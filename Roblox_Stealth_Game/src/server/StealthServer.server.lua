-- StealthServer (Script, goes in ServerScriptService)
-- Builds a private copy of the building for every player and runs their mission:
-- guard patrols, what guards can see and hear, takedowns, tools, and the final grade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("StealthConfig"))
local LevelDef = Config.Level

local VIEW_COS = math.cos(math.rad(Config.VIEW_HALF_ANGLE))
local CHASE_COS = math.cos(math.rad(80)) -- a guard who is chasing you sees much wider
local GUARD_Y = 3 -- height of a guard's middle above the floor

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "StealthRemotes"
local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local StartRemote = makeRemote("Start")       -- client -> server: (list of tool names)
local ActionRemote = makeRemote("Action")     -- client -> server: E key (takedown / fuse box)
local ToolRemote = makeRemote("UseTool")      -- client -> server: (toolName, aimPosition)
local CrouchRemote = makeRemote("Crouch")     -- client -> server: (isCrouching)
local RetryRemote = makeRemote("Retry")       -- client -> server
local ResultRemote = makeRemote("Result")     -- server -> client: (results table)
local FxRemote = makeRemote("Fx")             -- server -> client: (effectName, ...)
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------------
-- Night-time look
---------------------------------------------------------------------------
Lighting.ClockTime = 0
Lighting.Brightness = 0.4
Lighting.Ambient = Color3.fromRGB(42, 46, 64)
Lighting.OutdoorAmbient = Color3.fromRGB(30, 34, 50)
Lighting.FogColor = Color3.fromRGB(8, 10, 18)
Lighting.FogEnd = 400
Lighting.GlobalShadows = true
if not Lighting:FindFirstChild("StealthBloom") then
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "StealthBloom"
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StealthColor"
	cc.Contrast = 0.15
	cc.Saturation = -0.15
	cc.TintColor = Color3.fromRGB(225, 232, 255)
	cc.Parent = Lighting
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- A hidden spot to stand on for the split second between spawning and being moved into the building.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "StealthSpawn"
spawnPad.Anchored = true
spawnPad.Size = Vector3.new(30, 1, 30)
spawnPad.Position = Vector3.new(0, Config.BASE_HEIGHT, 0)
spawnPad.Transparency = 1
spawnPad.Parent = workspace

local missions = {} -- [player] = mission table
local slots = {}    -- which building spots are taken

local function makePart(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Turns level coordinates (x, z, height above the floor) into a world position.
local function P(m, x, z, y)
	return m.origin + Vector3.new(x, y or 0, z)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function setAttr(instance, name, value)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

-- Shortest distance from point p to the line segment a-b (ignoring height).
local function distToSegment(p, a, b)
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local len2 = ab:Dot(ab)
	local t = 0
	if len2 > 0.001 then
		t = math.clamp(ap:Dot(ab) / len2, 0, 1)
	end
	return (ap - ab * t).Magnitude
end

local function getCharacterParts(player)
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return hum, root, char
	end
	return nil
end

---------------------------------------------------------------------------
-- Building the level
---------------------------------------------------------------------------
local function addWall(m, spec)
	local cuts = { spec.from }
	for _, gap in ipairs(spec.gaps or {}) do
		table.insert(cuts, gap[1])
		table.insert(cuts, gap[2])
	end
	table.insert(cuts, spec.to)
	local h = Config.WALL_HEIGHT
	for i = 1, #cuts, 2 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a > 0.1 then
			local mid, len = (a + b) / 2, b - a
			local size, pos
			if spec.axis == "x" then
				size = Vector3.new(len + 1, h, 1)
				pos = P(m, mid, spec.fixed, h / 2)
			else
				size = Vector3.new(1, h, len + 1)
				pos = P(m, spec.fixed, mid, h / 2)
			end
			makePart(m.solid, {
				Name = "Wall", Size = size, Position = pos,
				Color = Color3.fromRGB(58, 60, 74), Material = Enum.Material.Concrete,
			})
			-- thin light strip on top so walls are easy to read from above
			makePart(m.level, {
				Name = "WallTrim", Size = Vector3.new(size.X, 0.15, size.Z),
				Position = pos + Vector3.new(0, h / 2 + 0.08, 0),
				Color = Color3.fromRGB(110, 115, 140), Material = Enum.Material.SmoothPlastic,
				CanCollide = false, CanQuery = false, CastShadow = false,
			})
		end
	end
end

local function buildLevel(m)
	local level = Instance.new("Model")
	level.Name = "Level_" .. m.player.UserId
	level:SetAttribute("Origin", m.origin)
	m.level = level

	m.solid = Instance.new("Folder")
	m.solid.Name = "Solid"
	m.solid.Parent = level
	m.guardsFolder = Instance.new("Folder")
	m.guardsFolder.Name = "Guards"
	m.guardsFolder.Parent = level

	local w, d = LevelDef.halfWidth * 2, LevelDef.halfDepth * 2
	makePart(level, {
		Name = "Floor", Size = Vector3.new(w + 4, 2, d + 4), Position = P(m, 0, 0, -1),
		Color = Color3.fromRGB(46, 40, 38), Material = Enum.Material.WoodPlanks,
	})

	for _, spec in ipairs(LevelDef.walls) do
		addWall(m, spec)
	end

	for _, c in ipairs(LevelDef.cover) do
		makePart(m.solid, {
			Name = "Cover", Size = Vector3.new(c[3], Config.COVER_HEIGHT, c[4]),
			Position = P(m, c[1], c[2], Config.COVER_HEIGHT / 2),
			Color = Color3.fromRGB(88, 66, 48), Material = Enum.Material.Wood,
		})
	end

	m.lamps = {}
	for _, l in ipairs(LevelDef.lamps) do
		makePart(level, {
			Name = "LampPost", Size = Vector3.new(0.4, 6, 0.4), Position = P(m, l[1], l[2], 3),
			Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Metal,
			CanCollide = false, CanQuery = false,
		})
		local bulb = makePart(level, {
			Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4),
			Position = P(m, l[1], l[2], 6.4), Color = Color3.fromRGB(255, 214, 150),
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Range = Config.LAMP_RADIUS + 6
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 214, 150)
		light.Shadows = true
		light.Parent = bulb
		table.insert(m.lamps, { bulb = bulb, light = light, pos = P(m, l[1], l[2], GUARD_Y) })
	end

	m.fuseBox = makePart(level, {
		Name = "FuseBox", Size = Vector3.new(1, 4, 3),
		Position = P(m, LevelDef.fuseBox[1], LevelDef.fuseBox[2], 3),
		Color = Color3.fromRGB(230, 190, 40), Material = Enum.Material.Metal,
	})
	m.exitPad = makePart(level, {
		Name = "ExitPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 9, 9),
		CFrame = CFrame.new(P(m, LevelDef.exit[1], LevelDef.exit[2], 0.15)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 255, 140), Material = Enum.Material.Neon,
		Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false,
	})

	m.rayParams = RaycastParams.new()
	m.rayParams.FilterType = Enum.RaycastFilterType.Include
	m.rayParams.FilterDescendantsInstances = { m.solid }

	level.Parent = workspace
end

local function buildGuard(m, spec, index)
	local model = Instance.new("Model")
	model.Name = "Guard" .. index
	local first = spec.points[1]
	local pos = P(m, first[1], first[2], GUARD_Y)

	local root = makePart(model, {
		Name = "Root", Size = Vector3.new(2, 5, 1), CFrame = CFrame.new(pos),
		Transparency = 1, CanCollide = false, CanQuery = false,
	})
	root:SetAttribute("State", "patrol")
	root:SetAttribute("Meter", 0)
	root:SetAttribute("Down", false)
	root:SetAttribute("IsTarget", spec.target == true)
	root:SetAttribute("GuardName", spec.name)

	-- The body is only for looks. Each player's client slides it smoothly after the Root.
	local body = Instance.new("Model")
	body.Name = "Body"
	local suit = spec.target and Color3.fromRGB(150, 25, 35) or Color3.fromRGB(34, 40, 62)
	local function bodyPart(name, size, offset, color, material)
		return makePart(body, {
			Name = name, Size = size, CFrame = CFrame.new(pos + offset), Color = color,
			Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false,
		})
	end
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), suit)
	bodyPart("Legs", Vector3.new(1.8, 2, 0.9), Vector3.new(0, -2, 0), Color3.fromRGB(20, 20, 26))
	bodyPart("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), Color3.fromRGB(226, 188, 160))
	bodyPart("Visor", Vector3.new(1, 0.25, 0.2), Vector3.new(0, 1.7, -0.6),
		spec.target and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(90, 220, 255), Enum.Material.Neon)
	body.PrimaryPart = torso
	body.Parent = model
	model.Parent = m.guardsFolder

	return {
		spec = spec, root = root, pos = pos, look = Vector3.new(0, 0, -1),
		state = "patrol", meter = 0, wp = 1, wpDir = 1, waitUntil = 0,
		path = nil, pathIndex = 1, token = 0, arrivedAt = nil,
		lastSeen = pos, lostAt = nil, noiseReadyAt = 0, down = false, found = false,
	}
end

local function spawnGuards(m)
	m.guardsFolder:ClearAllChildren()
	m.guards = {}
	for i, spec in ipairs(LevelDef.guards) do
		table.insert(m.guards, buildGuard(m, spec, i))
	end
end

---------------------------------------------------------------------------
-- Lights
---------------------------------------------------------------------------
local function setLights(m, on)
	m.lightsOff = not on
	for _, lamp in ipairs(m.lamps) do
		lamp.light.Enabled = on
		lamp.bulb.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		lamp.bulb.Color = on and Color3.fromRGB(255, 214, 150) or Color3.fromRGB(50, 50, 55)
	end
	setAttr(m.level, "LightsOff", not on)
end

local function cutPower(m)
	m.lightsOffUntil = os.clock() + Config.POWER_CUT_TIME
	setLights(m, false)
	FxRemote:FireClient(m.player, "PowerCut", Config.POWER_CUT_TIME)
end

local function isLit(m, point)
	if m.lightsOff then
		return false
	end
	for _, lamp in ipairs(m.lamps) do
		local dx, dz = lamp.pos.X - point.X, lamp.pos.Z - point.Z
		if dx * dx + dz * dz < Config.LAMP_RADIUS * Config.LAMP_RADIUS then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Seeing
---------------------------------------------------------------------------
-- True if nothing solid (and no smoke) is between a and b.
local function clearLine(m, a, b)
	for _, s in ipairs(m.smokes) do
		if distToSegment(s.pos, a, b) < s.radius then
			return false
		end
	end
	local origin = Vector3.new(a.X, m.origin.Y + 4.5, a.Z)
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if dir.Magnitude < 0.05 then
		return true
	end
	return workspace:Raycast(origin, dir, m.rayParams) == nil
end

local function canSee(m, g, point, range, cosLimit)
	local v = Vector3.new(point.X - g.pos.X, 0, point.Z - g.pos.Z)
	local d = v.Magnitude
	if d > range then
		return false, d
	end
	if d > 1 and g.look:Dot(v.Unit) < cosLimit then
		return false, d
	end
	if not clearLine(m, g.pos, point) then
		return false, d
	end
	return true, d
end

---------------------------------------------------------------------------
-- Guard movement
---------------------------------------------------------------------------
local function turnToward(g, point, dt)
	local v = Vector3.new(point.X - g.pos.X, 0, point.Z - g.pos.Z)
	if v.Magnitude < 0.05 then
		return
	end
	local mixed = g.look:Lerp(v.Unit, math.min(1, dt * 8))
	if mixed.Magnitude < 0.01 then
		mixed = v.Unit -- looking exactly the opposite way, just snap
	end
	g.look = mixed.Unit
end

-- Walks toward a point. Returns true once the guard is standing on it.
local function moveToward(g, point, speed, dt)
	local v = Vector3.new(point.X - g.pos.X, 0, point.Z - g.pos.Z)
	local dist = v.Magnitude
	if dist < 0.3 then
		return true
	end
	g.pos = g.pos + v.Unit * math.min(dist, speed * dt)
	turnToward(g, point, dt)
	return false
end

local function patrolPoint(m, g)
	local wp = g.spec.points[g.wp]
	return P(m, wp[1], wp[2], GUARD_Y)
end

local function computePath(fromPos, toPos, floorY)
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
	local a = Vector3.new(fromPos.X, floorY + 0.5, fromPos.Z)
	local b = Vector3.new(toPos.X, floorY + 0.5, toPos.Z)
	local ok = pcall(function()
		path:ComputeAsync(a, b)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local points = {}
		for _, wp in ipairs(path:GetWaypoints()) do
			table.insert(points, wp.Position)
		end
		if #points > 0 then
			return points
		end
	end
	return { toPos } -- no path found, walk straight there
end

-- Sends a guard somewhere off their patrol route ("investigate" or "return").
local function setGoal(m, g, point, state)
	g.state = state
	g.path = nil
	g.pathIndex = 1
	g.arrivedAt = nil
	g.token = g.token + 1
	local token = g.token
	task.spawn(function()
		local points = computePath(g.pos, point, m.origin.Y)
		if g.token == token and g.state == state and not g.down then
			g.path = points
		end
	end)
end

-- Follows the current path. Returns true when the guard reaches the end.
local function followPath(m, g, speed, dt)
	if not g.path then
		return false -- still working out the route
	end
	local target = g.path[g.pathIndex]
	if not target then
		return true
	end
	if moveToward(g, Vector3.new(target.X, m.origin.Y + GUARD_Y, target.Z), speed, dt) then
		g.pathIndex = g.pathIndex + 1
	end
	return g.path[g.pathIndex] == nil
end

local function patrolStep(m, g, dt, now)
	if now < g.waitUntil then
		return
	end
	if moveToward(g, patrolPoint(m, g), Config.GUARD_SPEED.patrol, dt) then
		g.waitUntil = now + (g.spec.points[g.wp][3] or 0)
		local n = #g.spec.points
		if g.spec.loop then
			g.wp = g.wp % n + 1
		else
			if g.wp + g.wpDir < 1 or g.wp + g.wpDir > n then
				g.wpDir = -g.wpDir
			end
			g.wp = g.wp + g.wpDir
		end
	end
end

---------------------------------------------------------------------------
-- Mission state changes
---------------------------------------------------------------------------
local function finishMission(m, success, reason)
	if m.state ~= "active" then
		return
	end
	m.state = "done"
	setAttr(m.level, "State", "done")
	local hum = getCharacterParts(m.player)
	if hum then
		hum.WalkSpeed = 0
	end

	local elapsed = os.clock() - m.startClock
	local result = {
		success = success, reason = reason, time = elapsed,
		spotted = m.spotted, bodiesFound = m.bodiesFound, takedowns = m.takedowns,
	}
	if success then
		local score = 100 - 25 * m.spotted - 10 * m.bodiesFound - 5 * m.takedowns
			- math.max(0, math.floor((elapsed - Config.PAR_TIME) / 10))
		score = math.max(0, score)
		local rank = "D"
		if score >= 95 then
			rank = "S"
		elseif score >= 80 then
			rank = "A"
		elseif score >= 60 then
			rank = "B"
		elseif score >= 40 then
			rank = "C"
		end
		result.score = score
		result.rank = rank
		local best = m.player:GetAttribute("BestScore")
		if not best or score > best then
			m.player:SetAttribute("BestScore", score)
			m.player:SetAttribute("BestRank", rank)
		end
	end
	ResultRemote:FireClient(m.player, result)
end

local function startChase(m, g, playerPos, countIt)
	if g.down or g.state == "chase" then
		return
	end
	g.state = "chase"
	g.meter = 1
	g.lastSeen = playerPos
	g.lostAt = nil
	g.path = nil
	g.token = g.token + 1
	if countIt then
		m.spotted = m.spotted + 1
		FxRemote:FireClient(m.player, "Alert", "SPOTTED")
	end
end

local function downGuard(m, g)
	g.down = true
	g.state = "down"
	g.meter = 0
	g.token = g.token + 1
	g.root:SetAttribute("Down", true)
	g.root:SetAttribute("State", "down")
	g.root:SetAttribute("Meter", 0)
	FxRemote:FireClient(m.player, "Takedown", g.pos, g.spec.target == true)
	if g.spec.target then
		m.targetDown = true
		setAttr(m.level, "TargetDown", true)
		setAttr(m.level, "Objective", "Target down. Get back to the exit in the storage room.")
		m.exitPad.Transparency = 0.3
	else
		m.takedowns = m.takedowns + 1
	end
end

local function resetMission(m)
	m.state = "briefing"
	m.spotted = 0
	m.bodiesFound = 0
	m.takedowns = 0
	m.targetDown = false
	m.smokes = {}
	m.tools = {}
	m.crouching = false
	m.lightsOffUntil = 0
	m.fuseReadyAt = 0
	m.startClock = os.clock()
	setLights(m, true)
	spawnGuards(m)
	m.exitPad.Transparency = 1
	setAttr(m.level, "State", "briefing")
	setAttr(m.level, "TargetDown", false)
	setAttr(m.level, "Lit", false)
	setAttr(m.level, "Crouching", false)
	setAttr(m.level, "Objective", "Take out " .. Config.Mission.target .. " without being seen.")
	for _, name in ipairs(Config.ToolOrder) do
		m.level:SetAttribute("Tool_" .. name, nil)
	end

	local hum, _, char = getCharacterParts(m.player)
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = 0 -- no jumping over cover
		hum.WalkSpeed = 0 -- frozen until the mission starts
		if m.hipHeight then
			hum.HipHeight = m.hipHeight
		end
		char:PivotTo(CFrame.new(P(m, LevelDef.start[1], LevelDef.start[2], 4)))
	end
end

---------------------------------------------------------------------------
-- Guard thinking (runs every frame while a mission is active)
---------------------------------------------------------------------------
local function stepGuard(m, g, dt, now, playerPos, range, noisy)
	if g.state == "chase" then
		local seen = canSee(m, g, playerPos, Config.VIEW_RANGE_LIT * 1.2, CHASE_COS)
		if seen then
			g.lastSeen = playerPos
			g.lostAt = nil
		elseif not g.lostAt then
			g.lostAt = now
		end
		local arrived = moveToward(g, g.lastSeen, Config.GUARD_SPEED.chase, dt)
		if arrived and not seen then
			g.look = CFrame.Angles(0, dt * 2.5, 0) * g.look -- look around
		end
		local d = Vector3.new(playerPos.X - g.pos.X, 0, playerPos.Z - g.pos.Z).Magnitude
		if seen and d < Config.CATCH_RANGE then
			finishMission(m, false, "CAUGHT")
			return
		end
		if g.lostAt and now - g.lostAt > Config.CHASE_GIVE_UP_TIME then
			g.meter = 0
			setGoal(m, g, patrolPoint(m, g), "return")
		end
		return
	end

	-- Detection meter: fills while the guard can see you, drains when they can't.
	local seen, d = canSee(m, g, playerPos, range, VIEW_COS)
	if seen then
		local fillTime = lerp(Config.DETECT_TIME_NEAR, Config.DETECT_TIME_FAR, d / range)
		g.meter = math.min(1, g.meter + dt / fillTime)
		if d < 4 then
			g.meter = 1
		end
	else
		g.meter = math.max(0, g.meter - Config.DETECT_DECAY * dt)
	end

	if g.meter >= 1 then
		if g.spec.target then
			-- The target doesn't chase. He panics and calls every guard nearby.
			m.spotted = m.spotted + 1
			FxRemote:FireClient(m.player, "Alert", "TARGET SAW YOU")
			g.meter = 0
			g.waitUntil = now + 6
			for _, other in ipairs(m.guards) do
				if not other.spec.target and (other.pos - g.pos).Magnitude < 45 then
					startChase(m, other, playerPos, false)
				end
			end
		else
			startChase(m, g, playerPos, true)
		end
		return
	end

	-- Hearing: walking near a patrolling guard makes them come and look.
	if noisy and g.state == "patrol" and not g.spec.target and now > g.noiseReadyAt then
		local nd = Vector3.new(playerPos.X - g.pos.X, 0, playerPos.Z - g.pos.Z).Magnitude
		if nd < Config.NOISE_RADIUS and (nd < 6 or clearLine(m, g.pos, playerPos)) then
			g.noiseReadyAt = now + 6
			setGoal(m, g, playerPos, "investigate")
		end
	end

	if seen and g.meter > 0.35 then
		turnToward(g, playerPos, dt) -- stops and stares at you
	elseif g.state == "patrol" then
		patrolStep(m, g, dt, now)
	elseif g.state == "investigate" then
		if g.arrivedAt then
			g.look = CFrame.Angles(0, dt * 1.8, 0) * g.look
			if now - g.arrivedAt > 3 then
				setGoal(m, g, patrolPoint(m, g), "return")
			end
		elseif followPath(m, g, Config.GUARD_SPEED.investigate, dt) then
			g.arrivedAt = now
		end
	elseif g.state == "return" then
		if followPath(m, g, Config.GUARD_SPEED.patrol, dt) then
			g.state = "patrol"
			g.path = nil
		end
	end
end

local function stepMission(m, dt)
	local now = os.clock()
	local hum, proot = getCharacterParts(m.player)
	if not hum then
		return
	end
	local playerPos = Vector3.new(proot.Position.X, m.origin.Y + GUARD_Y, proot.Position.Z)

	if m.lightsOff and now >= m.lightsOffUntil then
		setLights(m, true)
	end
	for i = #m.smokes, 1, -1 do
		if now >= m.smokes[i].untilTime then
			table.remove(m.smokes, i)
		end
	end

	local lit = isLit(m, playerPos)
	setAttr(m.level, "Lit", lit)
	local range = (lit and Config.VIEW_RANGE_LIT or Config.VIEW_RANGE_DARK)
		* (m.crouching and Config.CROUCH_RANGE_MULT or 1)
	local vel = proot.AssemblyLinearVelocity
	local noisy = (not m.crouching) and Vector3.new(vel.X, 0, vel.Z).Magnitude > 10

	for _, g in ipairs(m.guards) do
		if not g.down then
			stepGuard(m, g, dt, now, playerPos, range, noisy)
			if m.state ~= "active" then
				return
			end
			g.root.CFrame = CFrame.lookAt(g.pos, g.pos + g.look)
			setAttr(g.root, "State", g.state)
			setAttr(g.root, "Meter", math.floor(g.meter * 20 + 0.5) / 20)
		end
	end

	-- Guards who walk past a knocked-out guard notice the body.
	for _, body in ipairs(m.guards) do
		if body.down and not body.found then
			for _, g in ipairs(m.guards) do
				if not g.down and not g.spec.target and (g.state == "patrol" or g.state == "return")
					and canSee(m, g, body.pos, Config.BODY_SIGHT_RANGE, VIEW_COS) then
					body.found = true
					m.bodiesFound = m.bodiesFound + 1
					setGoal(m, g, body.pos, "investigate")
					FxRemote:FireClient(m.player, "Alert", "BODY FOUND")
					break
				end
			end
		end
	end

	if m.targetDown then
		local exit = P(m, LevelDef.exit[1], LevelDef.exit[2], GUARD_Y)
		if (playerPos - exit).Magnitude < 6 then
			finishMission(m, true)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	for _, m in pairs(missions) do
		if m.state == "active" then
			local ok, err = pcall(stepMission, m, dt)
			if not ok then
				warn("Stealth mission error: " .. tostring(err))
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Player input
---------------------------------------------------------------------------
StartRemote.OnServerEvent:Connect(function(player, loadout)
	local m = missions[player]
	local hum = getCharacterParts(player)
	if not m or m.state ~= "briefing" or not hum then
		return
	end
	m.tools = {}
	local count = 0
	if type(loadout) == "table" then
		for _, name in ipairs(loadout) do
			if type(name) == "string" and Config.Tools[name] and not m.tools[name]
				and count < Config.LOADOUT_SIZE then
				m.tools[name] = Config.Tools[name].uses
				m.level:SetAttribute("Tool_" .. name, m.tools[name])
				count = count + 1
			end
		end
	end
	m.startClock = os.clock()
	m.level:SetAttribute("StartTime", workspace:GetServerTimeNow())
	m.state = "active"
	setAttr(m.level, "State", "active")
	hum.WalkSpeed = Config.WALK_SPEED
end)

CrouchRemote.OnServerEvent:Connect(function(player, crouching)
	local m = missions[player]
	local hum = getCharacterParts(player)
	if not m or m.state ~= "active" or not hum then
		return
	end
	m.crouching = (crouching == true)
	setAttr(m.level, "Crouching", m.crouching)
	hum.WalkSpeed = m.crouching and Config.CROUCH_SPEED or Config.WALK_SPEED
	if m.hipHeight and hum.RigType == Enum.HumanoidRigType.R15 then
		hum.HipHeight = m.crouching and math.max(0.2, m.hipHeight - 1) or m.hipHeight
	end
end)

ActionRemote.OnServerEvent:Connect(function(player)
	local m = missions[player]
	local hum, proot = getCharacterParts(player)
	if not m or m.state ~= "active" or not hum then
		return
	end
	local playerPos = Vector3.new(proot.Position.X, m.origin.Y + GUARD_Y, proot.Position.Z)

	-- Takedown: you have to be close and NOT in front of them.
	local best, bestDist = nil, Config.TAKEDOWN_RANGE
	for _, g in ipairs(m.guards) do
		if not g.down and g.state ~= "chase" then
			local v = playerPos - g.pos
			local d = v.Magnitude
			if d < bestDist and (d < 0.5 or g.look:Dot(v.Unit) < 0.2) then
				best, bestDist = g, d
			end
		end
	end
	if best then
		downGuard(m, best)
		return
	end

	-- Fuse box
	local now = os.clock()
	if (playerPos - Vector3.new(m.fuseBox.Position.X, playerPos.Y, m.fuseBox.Position.Z)).Magnitude < 7 then
		if now >= m.fuseReadyAt and not m.lightsOff then
			m.fuseReadyAt = now + Config.FUSE_BOX_COOLDOWN
			cutPower(m)
		else
			FxRemote:FireClient(player, "Hint", "The fuse box is still resetting.")
		end
	end
end)

ToolRemote.OnServerEvent:Connect(function(player, toolName, aim)
	local m = missions[player]
	local hum, proot = getCharacterParts(player)
	if not m or m.state ~= "active" or not hum or type(toolName) ~= "string" then
		return
	end
	local def = Config.Tools[toolName]
	if not def or not m.tools[toolName] or m.tools[toolName] <= 0 then
		return
	end
	local playerPos = Vector3.new(proot.Position.X, m.origin.Y + GUARD_Y, proot.Position.Z)
	if typeof(aim) ~= "Vector3" or aim.X ~= aim.X or aim.Z ~= aim.Z then
		aim = playerPos + proot.CFrame.LookVector * 18
	end
	aim = Vector3.new(aim.X, playerPos.Y, aim.Z)

	if toolName == "NoiseMaker" then
		local v = aim - playerPos
		if v.Magnitude > def.range then
			aim = playerPos + v.Unit * def.range
		end
		for _, g in ipairs(m.guards) do
			if not g.down and not g.spec.target and g.state ~= "chase"
				and (g.pos - aim).Magnitude < def.hearRadius then
				setGoal(m, g, aim, "investigate")
			end
		end
		FxRemote:FireClient(player, "Noise", aim, def.hearRadius)
	elseif toolName == "Smoke" then
		table.insert(m.smokes, { pos = playerPos, radius = def.radius, untilTime = os.clock() + def.time })
		FxRemote:FireClient(player, "Smoke", playerPos, def.radius, def.time)
	elseif toolName == "Dart" then
		local best, bestDist = nil, def.aimSlack
		for _, g in ipairs(m.guards) do
			local d = (g.pos - aim).Magnitude
			if not g.down and d < bestDist then
				best, bestDist = g, d
			end
		end
		if not best then
			FxRemote:FireClient(player, "Hint", "Aim the dart at a guard.")
			return
		end
		if (best.pos - playerPos).Magnitude > def.range or not clearLine(m, playerPos, best.pos) then
			FxRemote:FireClient(player, "Hint", "No clear shot.")
			return
		end
		FxRemote:FireClient(player, "Dart", playerPos, best.pos)
		downGuard(m, best)
	elseif toolName == "PowerCutter" then
		cutPower(m)
	end

	m.tools[toolName] = m.tools[toolName] - 1
	m.level:SetAttribute("Tool_" .. toolName, m.tools[toolName])
end)

RetryRemote.OnServerEvent:Connect(function(player)
	local m = missions[player]
	if m and m.state == "done" then
		resetMission(m)
	end
end)

---------------------------------------------------------------------------
-- Players joining and leaving
---------------------------------------------------------------------------
local function onCharacter(player, char)
	local m = missions[player]
	if not m then
		return
	end
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then
		return
	end
	task.wait(0.3)
	if missions[player] ~= m or player.Character ~= char then
		return
	end
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	m.hipHeight = hum.HipHeight
	resetMission(m)
end

local function onPlayerAdded(player)
	local slot = 1
	while slots[slot] do
		slot = slot + 1
	end
	slots[slot] = player
	local m = {
		player = player, slot = slot,
		origin = Vector3.new(slot * Config.LEVEL_SPACING, Config.BASE_HEIGHT, 0),
		state = "briefing", guards = {}, smokes = {}, tools = {},
		spotted = 0, bodiesFound = 0, takedowns = 0, lightsOffUntil = 0, fuseReadyAt = 0,
		startClock = os.clock(),
	}
	buildLevel(m)
	missions[player] = m
	resetMission(m)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	local m = missions[player]
	if m then
		missions[player] = nil
		slots[m.slot] = nil
		m.level:Destroy()
	end
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end
