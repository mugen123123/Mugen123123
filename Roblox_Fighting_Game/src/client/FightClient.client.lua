-- FightClient (LocalScript, goes in StarterPlayer > StarterPlayerScripts)
-- Handles what each player sees and presses: the side camera, the HUD,
-- the attack buttons, and the visual effects. It never decides damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("FightConfig"))
local remotes = ReplicatedStorage:WaitForChild("FightRemotes")
local InputRemote = remotes:WaitForChild("Input")
local PickRemote = remotes:WaitForChild("PickFighter")
local FxRemote = remotes:WaitForChild("Fx")
local KnockbackRemote = remotes:WaitForChild("Knockback")
local State = ReplicatedStorage:WaitForChild("FightMatch")
local Model1 = State:WaitForChild("Model1")
local Model2 = State:WaitForChild("Model2")

local CENTER = Config.ARENA_CENTER
local FONT = Enum.Font.GothamBold

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function make(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function rootOf(model)
	if model and model.Parent then
		return model:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

-- 1 or 2 if the local player is fighting right now, otherwise nil
local function mySide()
	local char = player.Character
	if not char then
		return nil
	end
	if Model1.Value == char then
		return 1
	elseif Model2.Value == char then
		return 2
	end
	return nil
end

local function playSound(id, position, volume)
	local holder = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1,
		Size = Vector3.new(1, 1, 1), Position = position,
	}, workspace)
	local s = make("Sound", { SoundId = id, Volume = volume or 0.6 }, holder)
	s:Play()
	Debris:AddItem(holder, 2)
end

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "FightHud", ResetOnSpawn = false, IgnoreGuiInset = true,
}, player:WaitForChild("PlayerGui"))

local top = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.new(0.86, 0, 0, 90), BackgroundTransparency = 1, Visible = false,
}, gui)

local timerLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6),
	Size = UDim2.new(0, 70, 0, 40), BackgroundTransparency = 1, Font = FONT,
	TextSize = 34, TextColor3 = Color3.new(1, 1, 1), Text = "60",
	TextStrokeTransparency = 0.4,
}, top)

local function makeSide(side)
	local left = side == 1
	local anchorX = left and 0 or 1
	local align = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right

	local barBack = make("Frame", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(anchorX, 0, 0, 0),
		Size = UDim2.new(0.44, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(60, 15, 15),
		BorderSizePixel = 0,
	}, top)
	make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, barBack)
	-- health drains toward the outside edge, like most fighting games
	local fill = make("Frame", {
		AnchorPoint = Vector2.new(1 - anchorX, 0), Position = UDim2.new(1 - anchorX, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(80, 220, 90),
		BorderSizePixel = 0,
	}, barBack)

	local nameLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(anchorX, 0, 0, 28),
		Size = UDim2.new(0.34, 0, 0, 20), BackgroundTransparency = 1, Font = FONT,
		TextSize = 16, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = align,
		TextStrokeTransparency = 0.5, Text = "",
	}, top)
	local winsLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(1 - anchorX, 0),
		Position = UDim2.new(left and 0.44 or 0.56, 0, 0, 28),
		Size = UDim2.new(0.1, 0, 0, 20), BackgroundTransparency = 1, Font = FONT,
		TextSize = 16, TextColor3 = Color3.fromRGB(255, 210, 70),
		TextXAlignment = left and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
		Text = "",
	}, top)

	local meterBack = make("Frame", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(anchorX, 0, 0, 54),
		Size = UDim2.new(0.26, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(20, 25, 50),
		BorderSizePixel = 0,
	}, top)
	make("UIStroke", { Color = Color3.fromRGB(200, 200, 220), Thickness = 1 }, meterBack)
	local meterFill = make("Frame", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(anchorX, 0, 0, 0),
		Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(70, 140, 255),
		BorderSizePixel = 0,
	}, meterBack)
	for i = 1, 2 do -- lines that split the meter into 3 bars
		make("Frame", {
			Position = UDim2.new(i / 3, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
		}, meterBack)
	end

	local comboLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(anchorX, 0, 0, 110),
		Size = UDim2.new(0.3, 0, 0, 40), BackgroundTransparency = 1, Font = FONT,
		TextSize = 32, TextColor3 = Color3.fromRGB(255, 220, 80), TextXAlignment = align,
		TextStrokeTransparency = 0.3, Text = "", Visible = false,
	}, top)

	return {
		fill = fill, name = nameLabel, wins = winsLabel, meter = meterFill,
		combo = comboLabel, comboToken = 0,
	}
end

local sides = { makeSide(1), makeSide(2) }

local announceLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.38, 0),
	Size = UDim2.new(0.9, 0, 0, 90), BackgroundTransparency = 1, Font = FONT,
	TextSize = 64, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0,
	TextStrokeColor3 = Color3.fromRGB(180, 30, 30), Text = "", Visible = false,
}, gui)

local statusLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
	Size = UDim2.new(0.9, 0, 0, 22), BackgroundTransparency = 1, Font = FONT,
	TextSize = 16, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Text = "",
}, gui)

local hintLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(0.98, 0, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
	TextSize = 14, TextColor3 = Color3.fromRGB(220, 220, 220), TextStrokeTransparency = 0.5,
	Text = "A/D move   Space jump   J light   K heavy   H grab   L special   U EX special (1 bar)   I SUPER (3 bars)   F block",
	Visible = false,
}, gui)

local flash = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10,
}, gui)

-- Fighter select panel
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.55, 0),
	Size = UDim2.new(0, 190, 0, 210), BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	BackgroundTransparency = 0.2, BorderSizePixel = 0,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
make("TextLabel", {
	Position = UDim2.new(0, 0, 0, 6), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
	Font = FONT, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Text = "PICK YOUR FIGHTER",
}, panel)
local descLabel = make("TextLabel", {
	Position = UDim2.new(0, 8, 0, 160), Size = UDim2.new(1, -16, 0, 44), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(220, 220, 220),
	TextWrapped = true, Text = "",
}, panel)

local pickButtons = {}
local function showPick(id)
	for otherId, button in pairs(pickButtons) do
		button.BackgroundTransparency = (otherId == id) and 0 or 0.65
	end
	descLabel.Text = Config.Fighters[id].description .. " Used in your next fight."
end
for i, id in ipairs(Config.FighterOrder) do
	local def = Config.Fighters[id]
	local button = make("TextButton", {
		Position = UDim2.new(0, 10, 0, 34 + (i - 1) * 42), Size = UDim2.new(1, -20, 0, 36),
		BackgroundColor3 = def.color, Font = FONT, TextSize = 18,
		TextColor3 = Color3.fromRGB(20, 20, 20), Text = def.name, AutoButtonColor = true,
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	pickButtons[id] = button
	button.Activated:Connect(function()
		PickRemote:FireServer(id)
		showPick(id)
	end)
end
showPick(Config.DEFAULT_FIGHTER)

-- Big text in the middle of the screen (ROUND 1, FIGHT!, K.O. ...)
local announceToken = 0
State:GetAttributeChangedSignal("AnnounceId"):Connect(function()
	announceToken = announceToken + 1
	local token = announceToken
	announceLabel.Text = State:GetAttribute("Announce") or ""
	announceLabel.Visible = true
	announceLabel.TextSize = 90
	TweenService:Create(announceLabel, TweenInfo.new(0.2), { TextSize = 64 }):Play()
	task.delay(1.4, function()
		if announceToken == token then
			announceLabel.Visible = false
		end
	end)
end)

local function updateHud()
	local active = State:GetAttribute("Active") == true
	local side = mySide()
	top.Visible = active
	panel.Visible = side == nil
	hintLabel.Visible = side ~= nil
	if not active then
		statusLabel.Text = "Waiting for the next fight. Pick a fighter on the left."
		return
	end
	statusLabel.Text = side and "" or "Watching. Winner stays on, you're in line."
	timerLabel.Text = tostring(State:GetAttribute("Timer") or 0)
	for i = 1, 2 do
		local ui = sides[i]
		local hp = State:GetAttribute("HP" .. i) or 0
		local maxHp = State:GetAttribute("MaxHP" .. i) or 1
		local meter = State:GetAttribute("Meter" .. i) or 0
		local wins = State:GetAttribute("Wins" .. i) or 0
		local frac = math.clamp(hp / maxHp, 0, 1)
		ui.fill.Size = UDim2.new(frac, 0, 1, 0)
		ui.fill.BackgroundColor3 = (frac > 0.3) and Color3.fromRGB(80, 220, 90)
			or Color3.fromRGB(240, 70, 60)
		ui.name.Text = (State:GetAttribute("Name" .. i) or "")
			.. "  (" .. (State:GetAttribute("Fighter" .. i) or "") .. ")"
		ui.wins.Text = string.rep("★", wins)
		ui.meter.Size = UDim2.new(math.clamp(meter / Config.MAX_METER, 0, 1), 0, 1, 0)
		ui.meter.BackgroundColor3 = (meter >= Config.MAX_METER) and Color3.fromRGB(255, 200, 60)
			or Color3.fromRGB(70, 140, 255)
	end
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
local controlsBound = false

local function onAction(actionName, inputState)
	if inputState == Enum.UserInputState.Begin then
		InputRemote:FireServer(actionName, true)
	elseif actionName == "Block" and (inputState == Enum.UserInputState.End
		or inputState == Enum.UserInputState.Cancel) then
		InputRemote:FireServer(actionName, false)
	end
	return Enum.ContextActionResult.Sink
end

-- where the touch buttons go on phones/tablets
local touchSpots = {
	Light = UDim2.new(0.30, 0, 0.55, 0),
	Heavy = UDim2.new(0.55, 0, 0.30, 0),
	Grab = UDim2.new(0.05, 0, 0.55, 0),
	Special = UDim2.new(0.30, 0, 0.05, 0),
	Enhanced = UDim2.new(0.05, 0, 0.05, 0),
	Super = UDim2.new(0.55, 0, -0.2, 0),
	Block = UDim2.new(0.05, 0, 0.30, 0),
}

local function bindControls()
	if controlsBound then
		return
	end
	controlsBound = true
	for _, c in ipairs(Config.Controls) do
		ContextActionService:BindAction(c.action, onAction, true, c.key, c.pad)
		ContextActionService:SetTitle(c.action, c.title)
		ContextActionService:SetPosition(c.action, touchSpots[c.action])
	end
end

local function unbindControls()
	if not controlsBound then
		return
	end
	controlsBound = false
	for _, c in ipairs(Config.Controls) do
		ContextActionService:UnbindAction(c.action)
	end
	InputRemote:FireServer("Block", false)
end

KnockbackRemote.OnClientEvent:Connect(function(velocity)
	local root = rootOf(player.Character)
	if root then
		root.AssemblyLinearVelocity = velocity
	end
end)

---------------------------------------------------------------------------
-- Camera, facing, block shields (every frame)
---------------------------------------------------------------------------
local cameraTaken = false
local shields = {}

local function updateShield(model)
	local root = rootOf(model)
	local shield = shields[model]
	if root and model:GetAttribute("Blocking") then
		if not shield then
			shield = make("Part", {
				Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false,
				Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5),
				Material = Enum.Material.ForceField, Color = Color3.fromRGB(120, 200, 255),
			}, workspace)
			shields[model] = shield
		end
		shield.Position = root.Position + root.CFrame.LookVector * 1.2
	elseif shield then
		shield:Destroy()
		shields[model] = nil
	end
end

RunService.RenderStepped:Connect(function()
	updateHud()

	local active = State:GetAttribute("Active") == true
	local r1, r2 = rootOf(Model1.Value), rootOf(Model2.Value)
	local side = mySide()

	if side then
		bindControls()
	else
		unbindControls()
	end

	for model in pairs(shields) do
		if model ~= Model1.Value and model ~= Model2.Value then
			shields[model]:Destroy()
			shields[model] = nil
		end
	end

	if not (active and r1 and r2) then
		if cameraTaken then
			cameraTaken = false
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
		end
		return
	end

	updateShield(Model1.Value)
	updateShield(Model2.Value)

	-- Side-on camera that follows both fighters and zooms out when they move apart.
	cameraTaken = true
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 50
	local mid = (r1.Position + r2.Position) / 2
	local dist = math.abs(r1.Position.X - r2.Position.X)
	local focus = Vector3.new(mid.X, math.max(mid.Y, CENTER.Y + 3) + 1.5, CENTER.Z)
	local back = math.clamp(20 + dist * 0.6, 26, 60)
	local goal = CFrame.lookAt(focus + Vector3.new(0, 3, back), focus)
	camera.CFrame = camera.CFrame:Lerp(goal, 0.2)

	-- Keep my own fighter on the 2D line and facing the other fighter.
	if side then
		local mine = (side == 1) and r1 or r2
		local theirs = (side == 1) and r2 or r1
		local dir = (theirs.Position.X >= mine.Position.X) and 1 or -1
		local look = Vector3.new(dir, 0, 0)
		local pos = mine.Position
		if mine.CFrame.LookVector:Dot(look) < 0.99 or math.abs(pos.Z - CENTER.Z) > 0.3 then
			local fixed = Vector3.new(pos.X, pos.Y, CENTER.Z)
			mine.CFrame = CFrame.lookAt(fixed, fixed + look)
		end
	end
end)

---------------------------------------------------------------------------
-- Visual effects
---------------------------------------------------------------------------
local originalC0 = setmetatable({}, { __mode = "k" })

-- Swings an arm or leg by rotating its joint for a moment (no animation uploads needed).
local function swingJoint(model, r15Name, r6Name, r15Angle, r6Angle, duration)
	local joint, isR6
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			if d.Name == r15Name then
				joint = d
				break
			elseif d.Name == r6Name then
				joint, isR6 = d, true
				break
			end
		end
	end
	if not joint then
		return
	end
	local orig = originalC0[joint]
	if not orig then
		orig = joint.C0
		originalC0[joint] = orig
	end
	joint.C0 = orig * (isR6 and r6Angle or r15Angle)
	task.delay(duration, function()
		if joint.Parent then
			TweenService:Create(joint, TweenInfo.new(0.12), { C0 = orig }):Play()
		end
	end)
end

local UP90 = CFrame.Angles(math.rad(90), 0, 0)
local R6_RIGHT_UP = CFrame.Angles(0, 0, math.rad(90))
local R6_LEFT_UP = CFrame.Angles(0, 0, math.rad(-90))

local function burst(position, color, size, time)
	local p = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false,
		Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = color,
		Size = Vector3.new(1, 1, 1), Position = position,
	}, workspace)
	TweenService:Create(p, TweenInfo.new(time), {
		Size = Vector3.new(size, size, size), Transparency = 1,
	}):Play()
	Debris:AddItem(p, time + 0.1)
end

local projectiles = {}

local fx = {}

function fx.Swing(model, moveName, color)
	if not model or not model.Parent then
		return
	end
	local move = Config.Moves[moveName]
	local hold = move.startup + 0.12
	if moveName == "Light" then
		swingJoint(model, "RightShoulder", "Right Shoulder", UP90, R6_RIGHT_UP, hold)
	elseif moveName == "Heavy" then
		swingJoint(model, "RightHip", "Right Hip", UP90, R6_RIGHT_UP, hold)
	else
		swingJoint(model, "RightShoulder", "Right Shoulder", UP90, R6_RIGHT_UP, hold)
		swingJoint(model, "LeftShoulder", "Left Shoulder", UP90, R6_LEFT_UP, hold)
	end
	local root = rootOf(model)
	if root then
		if moveName == "Super" then
			burst(root.Position, color, 16, 0.5)
			flash.BackgroundTransparency = 0.4
			TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		elseif moveName == "Enhanced" then
			burst(root.Position, color, 8, 0.3)
		end
		playSound("rbxasset://sounds/swordlunge.wav", root.Position, 0.35)
	end
end

function fx.Hit(position, kind, attackerSide, combo)
	if kind == "block" then
		burst(position, Color3.fromRGB(120, 200, 255), 4, 0.2)
		playSound("rbxasset://sounds/unsheath.wav", position, 0.3)
		return
	end
	local size = (kind == "super" and 14) or (kind == "heavy" and 7) or 4
	burst(position, Color3.fromRGB(255, 240, 200), size, 0.25)
	burst(position, Color3.fromRGB(255, 120, 40), size * 0.6, 0.35)
	playSound("rbxasset://sounds/swordslash.wav", position, kind == "hit" and 0.5 or 0.9)

	local ui = sides[attackerSide]
	if ui and combo and combo >= 2 then
		ui.comboToken = ui.comboToken + 1
		local token = ui.comboToken
		ui.combo.Text = combo .. " HITS"
		ui.combo.Visible = true
		task.delay(1.5, function()
			if ui.comboToken == token then
				ui.combo.Visible = false
			end
		end)
	end
end

function fx.Projectile(id, origin, dir, speed, color, size)
	local part = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false,
		Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = color,
		Size = Vector3.new(size, size, size), Position = origin,
	}, workspace)
	make("PointLight", { Color = color, Range = 12, Brightness = 2 }, part)
	projectiles[id] = { part = part, origin = origin, dir = dir, speed = speed, start = os.clock() }
	Debris:AddItem(part, 6)
end

function fx.ProjectileEnd(id, position)
	local p = projectiles[id]
	if p then
		projectiles[id] = nil
		burst(position, p.part.Color, p.part.Size.X * 2.5, 0.25)
		p.part:Destroy()
	end
end

FxRemote.OnClientEvent:Connect(function(name, ...)
	local handler = fx[name]
	if handler then
		handler(...)
	end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for id, p in pairs(projectiles) do
		if p.part.Parent then
			local travelled = p.speed * (now - p.start)
			p.part.Position = p.origin + Vector3.new(p.dir * travelled, 0, 0)
		else
			projectiles[id] = nil
		end
	end
end)
