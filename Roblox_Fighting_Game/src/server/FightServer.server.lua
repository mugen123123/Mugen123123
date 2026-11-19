-- FightServer (Script, goes in ServerScriptService)
-- Runs the whole fight: builds the arena, picks who fights, checks hits,
-- handles damage, blocking, combos, meter, rounds and the training bot.
-- The server decides everything, so players can't cheat damage from their client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("FightConfig"))
local Moves = Config.Moves
local CENTER = Config.ARENA_CENTER
local ROOT_HEIGHT = 4 -- how high above the floor a character's root part sits when spawned

---------------------------------------------------------------------------
-- Remotes and shared state
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "FightRemotes"

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local InputRemote = makeRemote("Input")           -- client -> server: (action, isDown)
local PickRemote = makeRemote("PickFighter")      -- client -> server: (fighterId)
local FxRemote = makeRemote("Fx")                 -- server -> all clients: visual effects
local KnockbackRemote = makeRemote("Knockback")   -- server -> one client: (velocity)

-- Everything the HUD needs is stored as attributes on this folder.
local State = Instance.new("Folder")
State.Name = "FightMatch"
local Model1 = Instance.new("ObjectValue")
Model1.Name = "Model1"
Model1.Parent = State
local Model2 = Instance.new("ObjectValue")
Model2.Name = "Model2"
Model2.Parent = State
State:SetAttribute("Active", false)
State:SetAttribute("Fighting", false)
State:SetAttribute("Announce", "")
State:SetAttribute("AnnounceId", 0)
State:SetAttribute("Timer", Config.ROUND_TIME)
State:SetAttribute("Round", 1)
State.Parent = ReplicatedStorage
remotes.Parent = ReplicatedStorage

local function announce(text)
	State:SetAttribute("Announce", text)
	State:SetAttribute("AnnounceId", State:GetAttribute("AnnounceId") + 1)
end

---------------------------------------------------------------------------
-- Arena
---------------------------------------------------------------------------
local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function buildArena()
	local arena = Instance.new("Model")
	arena.Name = "FightArena"
	local width = Config.ARENA_HALF_WIDTH * 2 + 10
	local slippery = PhysicalProperties.new(0.7, 0, 0, 100, 100)

	makePart({
		Name = "Floor", Size = Vector3.new(width, 2, 30),
		Position = CENTER - Vector3.new(0, 1, 0),
		Color = Color3.fromRGB(35, 35, 45), Material = Enum.Material.Slate, Parent = arena,
	})
	makePart({
		Name = "FloorStripe", Size = Vector3.new(width, 0.1, 0.6),
		Position = CENTER + Vector3.new(0, 0.05, 3),
		Color = Color3.fromRGB(255, 80, 80), Material = Enum.Material.Neon,
		CanCollide = false, Parent = arena,
	})
	makePart({
		Name = "BackWall", Size = Vector3.new(width, 40, 2),
		Position = CENTER + Vector3.new(0, 19, -15),
		Color = Color3.fromRGB(20, 20, 30), Material = Enum.Material.Concrete, Parent = arena,
	})
	-- Glowing pillars on the back wall, just for looks
	for i = -4, 4 do
		makePart({
			Name = "Pillar", Size = Vector3.new(1, 30, 0.5),
			Position = CENTER + Vector3.new(i * 11, 15, -13.8),
			Color = (i % 2 == 0) and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 160, 255),
			Material = Enum.Material.Neon, CanCollide = false, Parent = arena,
		})
	end

	-- Invisible walls. Two keep fighters inside the arena, two keep them on the 2D line.
	for _, sign in ipairs({ -1, 1 }) do
		makePart({
			Name = "SideWall", Size = Vector3.new(1, 80, 30),
			Position = CENTER + Vector3.new(sign * (Config.ARENA_HALF_WIDTH + 0.5), 38, 0),
			Transparency = 1, CustomPhysicalProperties = slippery, Parent = arena,
		})
		makePart({
			Name = "PlaneWall", Size = Vector3.new(width, 80, 1),
			Position = CENTER + Vector3.new(0, 38, sign * 2.5),
			Transparency = 1, CustomPhysicalProperties = slippery, Parent = arena,
		})
	end

	-- Lobby where players wait for their turn
	local lobby = makePart({
		Name = "Lobby", Size = Vector3.new(60, 1, 24),
		Position = Config.LOBBY_POSITION - Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(45, 45, 60), Material = Enum.Material.SmoothPlastic, Parent = arena,
	})
	for _, off in ipairs({
		{ Vector3.new(0, 3, 12.5), Vector3.new(60, 6, 1) },
		{ Vector3.new(0, 3, -12.5), Vector3.new(60, 6, 1) },
		{ Vector3.new(30.5, 3, 0), Vector3.new(1, 6, 26) },
		{ Vector3.new(-30.5, 3, 0), Vector3.new(1, 6, 26) },
	}) do
		makePart({
			Name = "LobbyRail", Size = off[2], Position = lobby.Position + off[1],
			Transparency = 0.7, Color = Color3.fromRGB(120, 180, 255),
			Material = Enum.Material.Glass, Parent = arena,
		})
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Config.LOBBY_POSITION - Vector3.new(0, 0.4, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = arena

	arena.Parent = workspace
end

buildArena()

---------------------------------------------------------------------------
-- Characters and the queue
---------------------------------------------------------------------------
local queue = {} -- players waiting to fight, in order
local match = nil -- the match that is running right now (or nil)

local function lobbyCFrame()
	local offset = Vector3.new(math.random(-20, 20), 3, math.random(-6, 6))
	return CFrame.new(Config.LOBBY_POSITION + offset)
end

local function getParts(character)
	if not character or not character.Parent then
		return nil
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return hum, root
	end
	return nil
end

local function setupCharacter(character)
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	-- The game uses its own health number, so the normal Roblox health never runs out.
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.UseJumpPower = true
	task.wait(0.3)
	if character.Parent then
		character:PivotTo(lobbyCFrame())
	end
end

local function onPlayerAdded(player)
	player:SetAttribute("Fighter", Config.DEFAULT_FIGHTER)
	table.insert(queue, player)
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
end

local function removeFromQueue(player)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(removeFromQueue)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

PickRemote.OnServerEvent:Connect(function(player, fighterId)
	if type(fighterId) == "string" and Config.Fighters[fighterId] then
		player:SetAttribute("Fighter", fighterId)
	end
end)

---------------------------------------------------------------------------
-- Fighters
---------------------------------------------------------------------------
local function newFighter(model, player, side, fighterId)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local def = Config.Fighters[fighterId] or Config.Fighters[Config.DEFAULT_FIGHTER]

	local aura = Instance.new("Highlight")
	aura.Name = "FightAura"
	aura.FillTransparency = 1
	aura.OutlineColor = def.color
	aura.DepthMode = Enum.HighlightDepthMode.Occluded
	aura.Parent = model

	hum.AutoRotate = false
	hum.UseJumpPower = true
	model:SetAttribute("Blocking", false)

	return {
		model = model, humanoid = hum, root = root, player = player, side = side,
		def = def, aura = aura,
		name = player and player.DisplayName or "Training Bot",
		hp = def.maxHp, meter = 0,
		stunUntil = 0,    -- can't do anything until this time
		inHitstun = false, -- true if the stun came from a real hit (not a block)
		busyUntil = 0,    -- in the middle of an attack until this time
		armorUntil = 0,   -- super armor during the super's startup
		readyAt = 0,      -- projectile cooldown
		blockHeld = false,
		combo = 0,        -- hits in this fighter's current combo
		lastMove = nil, lastRank = 0, lightChain = 0, canCancel = false,
		moveToken = 0,    -- changes when a move gets interrupted
		moveDir = 0, nextThink = 0, -- bot only
	}
end

local function makeBot(sourceCharacter)
	sourceCharacter.Archivable = true
	local bot = sourceCharacter:Clone()
	sourceCharacter.Archivable = false
	bot.Name = "Training Bot"
	for _, d in ipairs(bot:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ForceField") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	local hum = bot:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = "Training Bot"
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	bot.Parent = workspace
	local root = bot:FindFirstChild("HumanoidRootPart")
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	return bot
end

local function fighterOf(player)
	if not match then
		return nil
	end
	for i = 1, 2 do
		if match.fighters[i].player == player then
			return match.fighters[i]
		end
	end
	return nil
end

local function fighterValid(f)
	if f.player and f.player.Parent ~= Players then
		return false
	end
	if f.player and f.player.Character ~= f.model then
		return false
	end
	return f.model.Parent ~= nil and f.root.Parent ~= nil and f.humanoid.Health > 0
end

local function addMeter(f, amount)
	f.meter = math.clamp(f.meter + amount, 0, Config.MAX_METER)
end

local function facingOf(f)
	local o = f.opponent
	return (o.root.Position.X >= f.root.Position.X) and 1 or -1
end

local function knockback(f, velocity)
	if f.player then
		KnockbackRemote:FireClient(f.player, velocity)
	else
		f.root.AssemblyLinearVelocity = velocity
	end
end

local function syncState(m)
	for i = 1, 2 do
		local f = m.fighters[i]
		State:SetAttribute("HP" .. i, math.max(0, math.floor(f.hp)))
		State:SetAttribute("Meter" .. i, math.floor(f.meter))
	end
end

---------------------------------------------------------------------------
-- Hits
---------------------------------------------------------------------------
local function applyHit(att, vic, move, isProjectile, hitPos)
	local now = os.clock()
	if vic.hp <= 0 then
		return
	end
	local dir = (vic.root.Position.X >= att.root.Position.X) and 1 or -1
	local baseDamage = move.damage * att.def.damageMult

	local stunned = now < vic.stunUntil
	local canBlock = vic.blockHeld
		and not move.unblockable
		and now >= vic.busyUntil
		and not (stunned and vic.inHitstun)

	if canBlock then
		local chip = math.floor(baseDamage * Config.CHIP_DAMAGE)
		vic.hp = math.max(1, vic.hp - chip) -- chip damage can't finish a round
		vic.stunUntil = now + move.blockstun
		vic.inHitstun = false
		att.canCancel = false
		att.combo = 0
		addMeter(att, move.meterGain * 0.5)
		addMeter(vic, 5)
		knockback(vic, Vector3.new(dir * move.knockX * 0.3, 0, 0))
		FxRemote:FireAllClients("Hit", hitPos, "block", att.side, 0)
		return
	end

	-- Combo counting: a hit that lands while they are still in hitstun keeps the combo going.
	if stunned and vic.inHitstun then
		att.combo = att.combo + 1
	else
		att.combo = 1
	end
	local n = att.combo - 1
	local damage = math.floor(baseDamage * math.max(0.3, 1 - 0.1 * n))   -- later hits do less
	local hitstun = move.hitstun * math.max(0.5, 1 - 0.07 * n)           -- and stun for less time

	vic.hp = math.max(0, vic.hp - damage)
	addMeter(att, move.meterGain)
	addMeter(vic, damage * 0.08)

	local armored = now < vic.armorUntil
	if not armored or vic.hp <= 0 then
		vic.stunUntil = now + hitstun
		vic.inHitstun = true
		vic.busyUntil = 0
		vic.canCancel = false
		vic.lightChain = 0
		vic.moveToken = vic.moveToken + 1 -- interrupts whatever they were doing
		knockback(vic, Vector3.new(dir * move.knockX, move.knockY, 0))
	end
	att.canCancel = not isProjectile

	local kind = "hit"
	if move.rank >= 5 then
		kind = "super"
	elseif move.rank >= 2 then
		kind = "heavy"
	end
	FxRemote:FireAllClients("Hit", hitPos, kind, att.side, att.combo)
end

local function spawnProjectile(m, f, move)
	local dir = facingOf(f)
	local size = f.def.projectileSize * (move.sizeMult or 1)
	local speed = f.def.projectileSpeed * (move.speedMult or 1)
	local origin = Vector3.new(f.root.Position.X + dir * 2.5, f.root.Position.Y + 0.5, CENTER.Z)
	m.projectileId = m.projectileId + 1
	local p = {
		id = m.projectileId, owner = f, move = move, dir = dir,
		x = origin.X, y = origin.Y, speed = speed, radius = size / 2, power = move.power or 1,
	}
	table.insert(m.projectiles, p)
	FxRemote:FireAllClients("Projectile", p.id, origin, dir, speed, f.def.color, size)
end

local function endProjectile(m, index)
	local p = m.projectiles[index]
	table.remove(m.projectiles, index)
	FxRemote:FireAllClients("ProjectileEnd", p.id, Vector3.new(p.x, p.y, CENTER.Z))
end

local function clearProjectiles(m)
	for i = #m.projectiles, 1, -1 do
		endProjectile(m, i)
	end
end

local function stepProjectiles(m, dt)
	local list = m.projectiles
	for _, p in ipairs(list) do
		p.x = p.x + p.dir * p.speed * dt
	end
	-- Projectiles from the two fighters cancel each other out (a stronger one wins).
	local dead = {}
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if a.owner ~= b.owner and math.abs(a.x - b.x) < a.radius + b.radius + 1
				and math.abs(a.y - b.y) < 3 then
				if a.power <= b.power then dead[a] = true end
				if b.power <= a.power then dead[b] = true end
			end
		end
	end
	for i = #list, 1, -1 do
		local p = list[i]
		local target = p.owner.opponent
		local tp = target.root.Position
		if dead[p] then
			endProjectile(m, i)
		elseif math.abs(p.x - tp.X) < p.radius + 1.5 and math.abs(p.y - tp.Y) < 3.5 then
			endProjectile(m, i)
			applyHit(p.owner, target, p.move, true, Vector3.new(p.x, p.y, CENTER.Z))
		elseif math.abs(p.x - CENTER.X) > Config.ARENA_HALF_WIDTH + 2 then
			endProjectile(m, i)
		end
	end
end

---------------------------------------------------------------------------
-- Doing a move
---------------------------------------------------------------------------
local function tryMove(f, name)
	local m = match
	local move = Moves[name]
	if not m or not m.active or not move then
		return false
	end
	local now = os.clock()
	if f.hp <= 0 or now < f.stunUntil then
		return false
	end
	if now < f.busyUntil then
		-- In the middle of another move. Only allowed if the last move hit and this one
		-- is a stronger kind of move (or the next light in a light chain).
		local chainLight = name == "Light" and f.lastMove == "Light"
			and f.lightChain < Config.MAX_LIGHT_CHAIN
		if not (f.canCancel and (move.rank > f.lastRank or chainLight)) then
			return false
		end
	else
		f.lightChain = 0
	end
	if move.cost > 0 and f.meter < move.cost then
		return false
	end
	if move.cooldown and now < f.readyAt then
		return false
	end
	if move.groundOnly and f.root.Position.Y - CENTER.Y > ROOT_HEIGHT + 1.5 then
		return false
	end

	addMeter(f, -move.cost)
	if move.cooldown then
		f.readyAt = now + move.cooldown
	end
	f.lightChain = (name == "Light") and (f.lightChain + 1) or 0
	f.canCancel = false
	f.lastMove = name
	f.lastRank = move.rank
	f.moveToken = f.moveToken + 1
	f.busyUntil = now + move.startup + move.recovery
	f.armorUntil = move.armor and (now + move.startup + 0.05) or 0
	local token = f.moveToken

	FxRemote:FireAllClients("Swing", f.model, name, f.def.color)

	task.delay(move.startup, function()
		if match ~= m or not m.active or f.moveToken ~= token or f.hp <= 0 then
			return
		end
		if move.projectile then
			spawnProjectile(m, f, move)
			return
		end
		local o = f.opponent
		local a, b = f.root.Position, o.root.Position
		if math.abs(b.X - a.X) > move.range or math.abs(b.Y - a.Y) > 5 then
			return -- whiffed
		end
		if move.groundOnly and b.Y - CENTER.Y > ROOT_HEIGHT + 1.5 then
			return -- can't grab someone who jumped
		end
		applyHit(f, o, move, false, (a + b) / 2 + Vector3.new(0, 0.5, 0))
	end)
	return true
end

InputRemote.OnServerEvent:Connect(function(player, action, isDown)
	local f = fighterOf(player)
	if not f or type(action) ~= "string" then
		return
	end
	if action == "Block" then
		f.blockHeld = (isDown == true)
	elseif Moves[action] then
		tryMove(f, action)
	end
end)

---------------------------------------------------------------------------
-- Training bot AI
---------------------------------------------------------------------------
local function botThink(f, now)
	local o = f.opponent
	local dx = o.root.Position.X - f.root.Position.X
	local dist = math.abs(dx)
	local dir = (dx >= 0) and 1 or -1
	local r = math.random()
	f.blockHeld = false
	f.moveDir = 0

	if now < f.stunUntil then
		return
	end
	if now < f.busyUntil then
		-- keep a combo going sometimes
		if f.canCancel and r < 0.6 then
			if f.lastMove == "Light" and f.lightChain < Config.MAX_LIGHT_CHAIN then
				tryMove(f, "Light")
			elseif f.lastRank < 2 then
				tryMove(f, "Heavy")
			elseif f.meter >= Config.MAX_METER then
				tryMove(f, "Super")
			end
		end
		return
	end

	if dist > 16 then
		f.moveDir = dir
		if r < 0.05 and f.meter >= Config.METER_BAR then
			tryMove(f, "Enhanced")
		elseif r < 0.2 then
			tryMove(f, "Special")
		end
	elseif dist > 6 then
		f.moveDir = dir
		if f.meter >= Config.MAX_METER and dist < 10 and r < 0.3 then
			tryMove(f, "Super")
		end
	else
		if now < o.busyUntil and r < 0.45 then
			f.blockHeld = true
		elseif r < 0.4 then
			tryMove(f, "Light")
		elseif r < 0.6 then
			tryMove(f, "Heavy")
		elseif r < 0.7 then
			tryMove(f, "Grab")
		elseif r < 0.8 then
			f.moveDir = -dir
		end
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function updateFighter(m, f, now)
	local stunned = now < f.stunUntil
	local busy = now < f.busyUntil
	local blocking = f.blockHeld and not busy and not (stunned and f.inHitstun) and f.hp > 0
	local locked = (not m.active) or stunned or busy or blocking or f.hp <= 0

	local speed = locked and 0 or f.def.speed
	local jump = locked and 0 or 50
	if f.humanoid.WalkSpeed ~= speed then
		f.humanoid.WalkSpeed = speed
	end
	if f.humanoid.JumpPower ~= jump then
		f.humanoid.JumpPower = jump
	end
	if f.model:GetAttribute("Blocking") ~= blocking then
		f.model:SetAttribute("Blocking", blocking)
	end

	if not f.player then
		-- The bot is controlled here. Players turn and move themselves on their client.
		if m.active and now >= f.nextThink then
			f.nextThink = now + 0.2
			botThink(f, now)
		elseif not m.active then
			f.moveDir = 0
			f.blockHeld = false
		end
		f.humanoid:Move(Vector3.new(f.moveDir, 0, 0), false)
		local pos = f.root.Position
		local look = Vector3.new(facingOf(f), 0, 0)
		if f.root.CFrame.LookVector:Dot(look) < 0.99 or math.abs(pos.Z - CENTER.Z) > 0.2 then
			local fixed = Vector3.new(pos.X, pos.Y, CENTER.Z)
			f.root.CFrame = CFrame.lookAt(fixed, fixed + look)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local m = match
	if not m then
		return
	end
	local now = os.clock()
	if not (fighterValid(m.fighters[1]) and fighterValid(m.fighters[2])) then
		return -- the match loop will notice and end the match
	end
	for i = 1, 2 do
		updateFighter(m, m.fighters[i], now)
	end
	if m.active then
		stepProjectiles(m, dt)
	end
	syncState(m)
end)

---------------------------------------------------------------------------
-- Match flow
---------------------------------------------------------------------------
local function startPosition(side)
	local dir = (side == 1) and -1 or 1
	local pos = CENTER + Vector3.new(dir * Config.START_OFFSET, ROOT_HEIGHT, 0)
	return CFrame.lookAt(pos, pos + Vector3.new(-dir, 0, 0))
end

local function resetForRound(f)
	f.hp = f.def.maxHp
	f.stunUntil = 0
	f.inHitstun = false
	f.busyUntil = 0
	f.armorUntil = 0
	f.readyAt = 0
	f.combo = 0
	f.canCancel = false
	f.lightChain = 0
	f.moveToken = f.moveToken + 1
	f.root.AssemblyLinearVelocity = Vector3.zero
	f.model:PivotTo(startPosition(f.side))
	if f.player then
		KnockbackRemote:FireClient(f.player, Vector3.zero)
	end
end

-- Returns the side that left/died, or nil if both fighters are still fine.
local function brokenSide(m)
	if not fighterValid(m.fighters[1]) then
		return 1
	end
	if not fighterValid(m.fighters[2]) then
		return 2
	end
	return nil
end

local function runMatch(p1, p2)
	local f1 = newFighter(p1.Character, p1, 1, p1:GetAttribute("Fighter"))
	local f2
	if p2 then
		f2 = newFighter(p2.Character, p2, 2, p2:GetAttribute("Fighter"))
	else
		local botId = Config.FighterOrder[math.random(1, #Config.FighterOrder)]
		f2 = newFighter(makeBot(p1.Character), nil, 2, botId)
		f2.aura.FillColor = Color3.fromRGB(60, 60, 70) -- grey tint so you can tell the bot apart
		f2.aura.FillTransparency = 0.4
	end
	f1.opponent = f2
	f2.opponent = f1

	local m = { fighters = { f1, f2 }, active = false, projectiles = {}, projectileId = 0 }
	local wins = { 0, 0 }

	Model1.Value = f1.model
	Model2.Value = f2.model
	for i = 1, 2 do
		local f = m.fighters[i]
		State:SetAttribute("Name" .. i, f.name)
		State:SetAttribute("Fighter" .. i, f.def.name)
		State:SetAttribute("MaxHP" .. i, f.def.maxHp)
		State:SetAttribute("Wins" .. i, 0)
	end
	State:SetAttribute("Timer", Config.ROUND_TIME)
	State:SetAttribute("Round", 1)
	syncState(m)
	match = m
	State:SetAttribute("Active", true)

	local matchWinner = nil
	local round = 0
	while not matchWinner and round < 5 do
		round = round + 1
		if brokenSide(m) then
			matchWinner = 3 - brokenSide(m)
			break
		end
		resetForRound(f1)
		resetForRound(f2)
		State:SetAttribute("Round", round)
		State:SetAttribute("Timer", Config.ROUND_TIME)
		announce("ROUND " .. round)
		task.wait(1.6)
		announce("FIGHT!")
		m.active = true
		State:SetAttribute("Fighting", true)

		local endsAt = os.clock() + Config.ROUND_TIME
		local left = Config.ROUND_TIME
		local broken = nil
		while true do
			left = endsAt - os.clock()
			State:SetAttribute("Timer", math.max(0, math.ceil(left)))
			broken = brokenSide(m)
			if broken or f1.hp <= 0 or f2.hp <= 0 or left <= 0 then
				break
			end
			task.wait(0.1)
		end

		m.active = false
		State:SetAttribute("Fighting", false)
		clearProjectiles(m)

		if broken then
			matchWinner = 3 - broken
			break
		end

		local roundWinner = nil
		local frac1, frac2 = f1.hp / f1.def.maxHp, f2.hp / f2.def.maxHp
		if frac1 > frac2 then
			roundWinner = 1
		elseif frac2 > frac1 then
			roundWinner = 2
		end
		if f1.hp <= 0 or f2.hp <= 0 then
			announce("K.O.")
		elseif roundWinner then
			announce("TIME UP")
		else
			announce("DRAW")
		end
		if roundWinner then
			wins[roundWinner] = wins[roundWinner] + 1
			State:SetAttribute("Wins" .. roundWinner, wins[roundWinner])
			if wins[roundWinner] >= Config.ROUNDS_TO_WIN then
				matchWinner = roundWinner
			end
		end
		task.wait(2.5)
	end

	if not matchWinner then
		matchWinner = (wins[1] >= wins[2]) and 1 or 2
	end
	announce(string.upper(m.fighters[matchWinner].name) .. " WINS")
	task.wait(3.5)

	-- Clean up
	match = nil
	State:SetAttribute("Active", false)
	State:SetAttribute("Fighting", false)
	Model1.Value = nil
	Model2.Value = nil
	for i = 1, 2 do
		local f = m.fighters[i]
		if f.player then
			if f.model.Parent then
				f.aura:Destroy()
				f.model:SetAttribute("Blocking", false)
				f.humanoid.WalkSpeed = 16
				f.humanoid.JumpPower = 50
				f.humanoid.AutoRotate = true
				f.model:PivotTo(lobbyCFrame())
			end
		else
			f.model:Destroy()
		end
	end

	return m.fighters[matchWinner].player, m.fighters[3 - matchWinner].player
end

-- Main loop: whenever nobody is fighting, start the next match.
-- With one player you fight the training bot. With two or more, the first two in line fight.
-- The winner stays on and the loser goes to the back of the line.
while true do
	task.wait(1)
	local ready = {}
	for _, p in ipairs(queue) do
		if p.Parent == Players and getParts(p.Character) then
			table.insert(ready, p)
		end
	end
	if #ready >= 1 then
		for i = 3, 1, -1 do
			announce("NEXT FIGHT IN " .. i)
			task.wait(1)
		end
		local p1, p2 = ready[1], ready[2]
		local ok1 = p1.Parent == Players and getParts(p1.Character)
		local ok2 = p2 and p2.Parent == Players and getParts(p2.Character)
		if ok1 and (ok2 or not p2) then
			local success, winner, loser = pcall(runMatch, p1, p2)
			if not success then
				warn("Fight match error: " .. tostring(winner))
				match = nil
				local leftover = workspace:FindFirstChild("Training Bot")
				if leftover then
					leftover:Destroy()
				end
				State:SetAttribute("Active", false)
				State:SetAttribute("Fighting", false)
				winner, loser = nil, nil
			end
			if winner and winner.Parent == Players then
				removeFromQueue(winner)
				table.insert(queue, 1, winner)
			end
			if loser and loser.Parent == Players then
				removeFromQueue(loser)
				table.insert(queue, loser)
			end
		end
	end
end
