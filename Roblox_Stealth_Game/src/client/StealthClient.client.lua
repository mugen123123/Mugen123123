-- StealthClient (LocalScript, goes in StarterPlayer > StarterPlayerScripts)
-- What the player sees and presses: the overhead camera, guard vision cones,
-- the HUD, the briefing and results screens, and effects. It never decides
-- whether you were seen. The server does that.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("StealthConfig"))
local remotes = ReplicatedStorage:WaitForChild("StealthRemotes")
local StartRemote = remotes:WaitForChild("Start")
local ActionRemote = remotes:WaitForChild("Action")
local ToolRemote = remotes:WaitForChild("UseTool")
local CrouchRemote = remotes:WaitForChild("Crouch")
local RetryRemote = remotes:WaitForChild("Retry")
local ResultRemote = remotes:WaitForChild("Result")
local FxRemote = remotes:WaitForChild("Fx")

local level = workspace:WaitForChild("Level_" .. player.UserId)
local guardsFolder = level:WaitForChild("Guards")
local solid = level:WaitForChild("Solid")
local origin = level:GetAttribute("Origin")

local FONT = Enum.Font.GothamBold
local FONT_LIGHT = Enum.Font.Gotham
local HALF_ANGLE = math.rad(Config.VIEW_HALF_ANGLE)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "StealthFx"
fxFolder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { solid }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function make(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function myRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function playSound(id, volume)
	local s = make("Sound", { SoundId = id, Volume = volume or 0.5 }, fxFolder)
	s:Play()
	Debris:AddItem(s, 3)
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "StealthHud", ResetOnSpawn = false, IgnoreGuiInset = true,
}, player:WaitForChild("PlayerGui"))

local function label(props, parent)
	local base = {
		BackgroundTransparency = 1, Font = FONT, TextColor3 = Color3.new(1, 1, 1),
		TextSize = 16, TextStrokeTransparency = 0.6, Text = "",
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return make("TextLabel", base, parent or gui)
end

local function panel(props, parent)
	local base = {
		BackgroundColor3 = Color3.fromRGB(14, 16, 24), BackgroundTransparency = 0.12, BorderSizePixel = 0,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local frame = make("Frame", base, parent or gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
	make("UIStroke", { Color = Color3.fromRGB(70, 76, 100), Thickness = 1 }, frame)
	return frame
end

local missionLabel = label({
	Position = UDim2.new(0, 20, 0, 52), Size = UDim2.new(0, 400, 0, 22), TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left, Text = Config.Mission.name,
})
local objectiveLabel = label({
	Position = UDim2.new(0, 20, 0, 76), Size = UDim2.new(0, 520, 0, 20), Font = FONT_LIGHT,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(215, 220, 235),
})
local timerLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50),
	Size = UDim2.new(0, 120, 0, 34), TextSize = 30, Text = "0:00",
})
local statusLabel = label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -62),
	Size = UDim2.new(0, 300, 0, 28), TextSize = 22,
})
local promptLabel = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.66, 0),
	Size = UDim2.new(0, 400, 0, 30), TextSize = 22, TextColor3 = Color3.fromRGB(255, 225, 120),
})
local hintLabel = label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.new(0.8, 0, 0, 24), TextSize = 18, TextColor3 = Color3.fromRGB(255, 190, 120),
})
local controlsLabel = label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.96, 0, 0, 20), Font = FONT_LIGHT, TextSize = 14,
	TextColor3 = Color3.fromRGB(190, 195, 210),
	Text = "WASD move    C crouch (quiet, harder to see)    E takedown from behind / use    Q and R tools (aim with mouse)",
})
local alertLabel = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.26, 0),
	Size = UDim2.new(0.8, 0, 0, 60), TextSize = 48, TextColor3 = Color3.fromRGB(255, 70, 70),
	TextStrokeTransparency = 0, Visible = false,
})
local flash = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 40, 40),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5,
}, gui)

-- Tool slots (bottom right)
local toolSlots = {}
for i = 1, Config.LOADOUT_SIZE do
	local frame = panel({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20 - (Config.LOADOUT_SIZE - i) * 170, 1, -44),
		Size = UDim2.new(0, 160, 0, 54), Visible = false,
	})
	local nameLabel = label({
		Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -20, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
	local countLabel = label({
		Position = UDim2.new(0, 10, 0, 28), Size = UDim2.new(1, -20, 0, 18), Font = FONT_LIGHT,
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 195, 210),
	}, frame)
	toolSlots[i] = { frame = frame, name = nameLabel, count = countLabel }
end
local TOOL_KEYS = { "Q", "R" }

---------------------------------------------------------------------------
-- Briefing screen
---------------------------------------------------------------------------
local selected = {} -- tool names in the order they were picked

local briefing = panel({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 520, 0, 470), Visible = false,
})
label({
	Position = UDim2.new(0, 24, 0, 18), Size = UDim2.new(1, -48, 0, 18), TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 90, 90), Text = "CONTRACT",
}, briefing)
label({
	Position = UDim2.new(0, 24, 0, 38), Size = UDim2.new(1, -48, 0, 32), TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left, Text = Config.Mission.name,
}, briefing)
label({
	Position = UDim2.new(0, 24, 0, 76), Size = UDim2.new(1, -48, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 200, 60),
	Text = "Target: " .. Config.Mission.target .. " (red suit)",
}, briefing)
label({
	Position = UDim2.new(0, 24, 0, 102), Size = UDim2.new(1, -48, 0, 92), Font = FONT_LIGHT, TextSize = 15,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(215, 220, 235), Text = Config.Mission.briefing,
}, briefing)
local pickTitle = label({
	Position = UDim2.new(0, 24, 0, 200), Size = UDim2.new(1, -48, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left,
}, briefing)

local toolButtons = {}
local function refreshToolButtons()
	pickTitle.Text = "PICK " .. Config.LOADOUT_SIZE .. " TOOLS  (" .. #selected .. "/" .. Config.LOADOUT_SIZE .. ")"
	for name, button in pairs(toolButtons) do
		local on = table.find(selected, name) ~= nil
		button.BackgroundColor3 = on and Color3.fromRGB(190, 40, 50) or Color3.fromRGB(34, 38, 54)
	end
end
for i, name in ipairs(Config.ToolOrder) do
	local def = Config.Tools[name]
	local button = make("TextButton", {
		Position = UDim2.new(0, 24, 0, 226 + (i - 1) * 46), Size = UDim2.new(1, -48, 0, 40),
		BackgroundColor3 = Color3.fromRGB(34, 38, 54), BorderSizePixel = 0, Text = "", AutoButtonColor = true,
	}, briefing)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	label({
		Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(1, -20, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, Text = def.name .. "  x" .. def.uses,
	}, button)
	label({
		Position = UDim2.new(0, 10, 0, 20), Size = UDim2.new(1, -20, 0, 16), Font = FONT_LIGHT, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 205, 220),
		Text = def.description,
	}, button)
	toolButtons[name] = button
	button.Activated:Connect(function()
		local at = table.find(selected, name)
		if at then
			table.remove(selected, at)
		elseif #selected < Config.LOADOUT_SIZE then
			table.insert(selected, name)
		end
		refreshToolButtons()
	end)
end
refreshToolButtons()

local startButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.new(0, 220, 0, 42), BackgroundColor3 = Color3.fromRGB(210, 45, 55), BorderSizePixel = 0,
	Font = FONT, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Text = "START MISSION",
}, briefing)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, startButton)
startButton.Activated:Connect(function()
	StartRemote:FireServer(selected)
end)

---------------------------------------------------------------------------
-- Results screen
---------------------------------------------------------------------------
local results = panel({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 420, 0, 380), Visible = false,
})
local resultTitle = label({
	Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 30), TextSize = 26,
}, results)
local rankLabel = label({
	Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 0, 110), TextSize = 110,
	TextColor3 = Color3.fromRGB(255, 200, 60),
}, results)
local statsLabel = label({
	Position = UDim2.new(0, 40, 0, 172), Size = UDim2.new(1, -80, 0, 130), Font = FONT_LIGHT, TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(215, 220, 235),
}, results)
local retryButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -98, 1, -18),
	Size = UDim2.new(0, 184, 0, 42), BackgroundColor3 = Color3.fromRGB(210, 45, 55), BorderSizePixel = 0,
	Font = FONT, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Text = "PLAY AGAIN",
}, results)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, retryButton)
retryButton.Activated:Connect(function()
	results.Visible = false
	RetryRemote:FireServer()
end)
local menuButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 98, 1, -18),
	Size = UDim2.new(0, 184, 0, 42), BackgroundColor3 = Color3.fromRGB(40, 44, 62), BorderSizePixel = 0,
	Font = FONT, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Text = "MAIN MENU",
}, results)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, menuButton)
menuButton.Activated:Connect(function()
	results.Visible = false
	RetryRemote:FireServer()
	player:SetAttribute("InMenu", true) -- StealthMenu sees this and takes the camera back
end)

ResultRemote.OnClientEvent:Connect(function(r)
	if r.success then
		resultTitle.Text = "CONTRACT COMPLETE"
		resultTitle.TextColor3 = Color3.fromRGB(120, 255, 160)
		rankLabel.Text = r.rank
		statsLabel.Text = "Time: " .. formatTime(r.time) .. "  (par " .. formatTime(Config.PAR_TIME) .. ")"
			.. "\nTimes spotted: " .. r.spotted
			.. "\nBodies found: " .. r.bodiesFound
			.. "\nExtra takedowns: " .. r.takedowns
			.. "\nScore: " .. r.score .. " / 100"
	else
		resultTitle.Text = "CONTRACT FAILED"
		resultTitle.TextColor3 = Color3.fromRGB(255, 90, 90)
		rankLabel.Text = "X"
		statsLabel.Text = "You were " .. string.lower(r.reason or "caught") .. "."
			.. "\nTime: " .. formatTime(r.time)
			.. "\n\nTip: stay out of the light, crouch near guards, and come at them from behind."
	end
	results.Visible = true
end)

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
local crouching = false

local function isActive()
	return level:GetAttribute("State") == "active"
end

-- Where the mouse points on the floor. Without a mouse, a spot in front of the character.
local function aimPoint()
	local root = myRoot()
	if not root then
		return nil
	end
	if UserInputService.MouseEnabled then
		local loc = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(loc.X, loc.Y)
		if ray.Direction.Y < -0.01 then
			local t = (origin.Y + 3 - ray.Origin.Y) / ray.Direction.Y
			return ray.Origin + ray.Direction * t
		end
	end
	return root.Position + root.CFrame.LookVector * 18
end

local function useTool(slot)
	local name = selected[slot]
	if name and (level:GetAttribute("Tool_" .. name) or 0) > 0 then
		ToolRemote:FireServer(name, aimPoint())
	end
end

local function onAction(actionName, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if not isActive() then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "StealthCrouch" then
		crouching = not crouching
		CrouchRemote:FireServer(crouching)
	elseif actionName == "StealthAction" then
		ActionRemote:FireServer()
	elseif actionName == "StealthTool1" then
		useTool(1)
	elseif actionName == "StealthTool2" then
		useTool(2)
	end
	return Enum.ContextActionResult.Sink
end

local binds = {
	{ "StealthCrouch", "Crouch", UDim2.new(0.05, 0, 0.5, 0), Enum.KeyCode.C, Enum.KeyCode.ButtonB },
	{ "StealthAction", "Action", UDim2.new(0.35, 0, 0.5, 0), Enum.KeyCode.E, Enum.KeyCode.ButtonX },
	{ "StealthTool1", "Tool 1", UDim2.new(0.05, 0, 0.15, 0), Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 },
	{ "StealthTool2", "Tool 2", UDim2.new(0.35, 0, 0.15, 0), Enum.KeyCode.R, Enum.KeyCode.ButtonR1 },
}
for _, b in ipairs(binds) do
	ContextActionService:BindAction(b[1], onAction, true, b[4], b[5])
	ContextActionService:SetTitle(b[1], b[2])
	ContextActionService:SetPosition(b[1], b[3])
end

---------------------------------------------------------------------------
-- Guard visuals: animated characters, vision cones, markers and speech
---------------------------------------------------------------------------
local visuals = {}
local rigsFolder = ReplicatedStorage:WaitForChild("StealthRigs", 10)
local CONE_SEGMENTS = 14
local CONE_THICKNESS = 0.04
-- Roblox's own default R15 animations
local ANIMATIONS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
}

-- Welds an extra piece (cap, vest, tie...) onto part of a character.
local function attach(rig, limbName, size, offset, color, material, cylinder)
	local limb = rig:FindFirstChild(limbName)
	if not limb then
		return nil
	end
	local p = make("Part", {
		Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic,
		CanCollide = false, CanQuery = false, CanTouch = false, Massless = true,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
		CFrame = limb.CFrame * offset,
	}, rig)
	pcall(function()
		p.CollisionGroup = "StealthGhost"
	end)
	if cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	make("WeldConstraint", { Part0 = limb, Part1 = p }, p)
	return p
end

local function dressRig(rig, isTarget)
	local torso = rig:FindFirstChild("UpperTorso")
	local hips = rig:FindFirstChild("LowerTorso")
	local head = rig:FindFirstChild("Head")
	if not (torso and head) then
		return
	end
	local front = -(torso.Size.Z / 2)
	local headWidth = math.min(head.Size.X, head.Size.Z) + 0.2
	if isTarget then
		-- white shirt, gold tie, slick hair
		attach(rig, "UpperTorso", Vector3.new(0.62, torso.Size.Y * 0.82, 0.04), CFrame.new(0, 0.05, front - 0.02),
			Color3.fromRGB(238, 236, 228))
		attach(rig, "UpperTorso", Vector3.new(0.22, torso.Size.Y * 0.74, 0.05), CFrame.new(0, 0.02, front - 0.05),
			Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
		attach(rig, "Head", Vector3.new(headWidth, 0.32, headWidth), CFrame.new(0, head.Size.Y / 2 + 0.06, 0.05),
			Color3.fromRGB(38, 28, 22))
	else
		-- dark vest with a chest light, belt, and a cap
		attach(rig, "UpperTorso", torso.Size + Vector3.new(0.14, 0.04, 0.16), CFrame.new(),
			Color3.fromRGB(20, 22, 30), Enum.Material.Fabric)
		attach(rig, "UpperTorso", Vector3.new(0.6, 0.14, 0.06), CFrame.new(0.32, 0.28, front - 0.1),
			Color3.fromRGB(90, 220, 255), Enum.Material.Neon)
		if hips then
			attach(rig, "LowerTorso", Vector3.new(hips.Size.X + 0.14, 0.22, hips.Size.Z + 0.16),
				CFrame.new(0, hips.Size.Y / 2 - 0.1, 0), Color3.fromRGB(10, 10, 12))
			attach(rig, "LowerTorso", Vector3.new(0.3, 0.2, 0.06),
				CFrame.new(0, hips.Size.Y / 2 - 0.1, -(hips.Size.Z / 2 + 0.1)), Color3.fromRGB(214, 170, 90), Enum.Material.Metal)
		end
		attach(rig, "Head", Vector3.new(0.4, headWidth, headWidth),
			CFrame.new(0, head.Size.Y / 2 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(22, 28, 48), Enum.Material.Fabric, true)
		attach(rig, "Head", Vector3.new(headWidth * 0.9, 0.08, 0.5),
			CFrame.new(0, head.Size.Y / 2 - 0.04, -(headWidth / 2 + 0.1)), Color3.fromRGB(22, 28, 48), Enum.Material.Fabric)
	end
end

-- Returns the character model, its animation tracks, and how much higher than the
-- server's Root its middle sits.
local function buildRig(isTarget, cf)
	local template = rigsFolder and rigsFolder:FindFirstChild(isTarget and "TargetRig" or "GuardRig")
	if template then
		local rig = template:Clone()
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local hrp = rig:FindFirstChild("HumanoidRootPart")
		if hum and hrp then
			for _, d in ipairs(rig:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					pcall(function()
						d.CollisionGroup = "StealthGhost"
					end)
				end
			end
			hrp.Anchored = true
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			pcall(function()
				hum.EvaluateStateMachine = false
			end)
			rig.PrimaryPart = hrp
			rig:PivotTo(cf)
			rig.Parent = fxFolder
			pcall(dressRig, rig, isTarget)

			local tracks = {}
			pcall(function()
				local animator = hum:FindFirstChildOfClass("Animator") or make("Animator", {}, hum)
				for name, id in pairs(ANIMATIONS) do
					local animation = Instance.new("Animation")
					animation.AnimationId = id
					local track = animator:LoadAnimation(animation)
					track.Looped = true
					track.Priority = (name == "idle") and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
					tracks[name] = track
				end
			end)
			return rig, tracks, (hum.HipHeight + hrp.Size.Y / 2) - 3
		end
		rig:Destroy()
	end

	-- Fallback if the character rigs could not be made: a simple block figure.
	local rig = Instance.new("Model")
	local suit = isTarget and Color3.fromRGB(150, 25, 35) or Color3.fromRGB(34, 40, 62)
	local function piece(size, offset, color, material)
		return make("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Size = size,
			CFrame = cf * CFrame.new(offset), Color = color, Material = material or Enum.Material.SmoothPlastic,
		}, rig)
	end
	rig.PrimaryPart = piece(Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), suit)
	piece(Vector3.new(1.8, 2, 0.9), Vector3.new(0, -2, 0), Color3.fromRGB(20, 20, 26))
	piece(Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), Color3.fromRGB(226, 188, 160))
	piece(Vector3.new(1, 0.25, 0.2), Vector3.new(0, 1.7, -0.6), Color3.fromRGB(90, 220, 255), Enum.Material.Neon)
	rig.Parent = fxFolder
	return rig, {}, 0
end

local function createVisual(guardModel, root)
	local isTarget = root:GetAttribute("IsTarget") == true
	local rig, tracks, yOffset = buildRig(isTarget, root.CFrame)

	local tris = {}
	for i = 1, CONE_SEGMENTS do
		local pair = {}
		for k = 1, 2 do
			pair[k] = make("WedgePart", {
				Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
				Material = Enum.Material.Neon, Transparency = 1, Size = Vector3.new(CONE_THICKNESS, 1, 1),
				TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
			}, fxFolder)
		end
		tris[i] = pair
	end

	local billboard = make("BillboardGui", {
		Adornee = root, Size = UDim2.new(0, 260, 0, 76), StudsOffset = Vector3.new(0, 5.5, 0), AlwaysOnTop = true,
		ResetOnSpawn = false,
	}, player.PlayerGui)
	local mark = label({ Size = UDim2.new(1, 0, 0, 40), TextSize = 34, TextStrokeTransparency = 0 }, billboard)
	local bark = label({
		Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 24), Font = FONT_LIGHT, TextSize = 16,
		TextStrokeTransparency = 0.2,
	}, billboard)

	local v = {
		rig = rig, tracks = tracks, yOffset = yOffset, tris = tris, billboard = billboard, mark = mark, bark = bark,
		lastRootPos = root.Position, speed = 0, anim = nil, lastState = nil, barkUntil = 0,
	}
	visuals[guardModel] = v
	return v
end

local function destroyVisual(guardModel)
	local v = visuals[guardModel]
	if v then
		v.rig:Destroy()
		for _, pair in ipairs(v.tris) do
			pair[1]:Destroy()
			pair[2]:Destroy()
		end
		v.billboard:Destroy()
		visuals[guardModel] = nil
	end
end

-- Lays two wedge parts flat so together they fill the triangle a-b-c.
local function drawTriangle(a, b, c, w1, w2)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 0.001 or bc.Magnitude < 0.001 then
		return false
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	w1.Size = Vector3.new(CONE_THICKNESS, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	w2.Size = Vector3.new(CONE_THICKNESS, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	return true
end

local BARKS = {
	chase = "HEY! Stop right there!",
	investigate = "Huh? What was that?",
	lost = "Lost them...",
	nothing = "Must have been nothing.",
}

local function updateGuards(viewRange, dt)
	for guardModel in pairs(visuals) do
		if guardModel.Parent ~= guardsFolder then
			destroyVisual(guardModel)
		end
	end
	local now = os.clock()

	for _, guardModel in ipairs(guardsFolder:GetChildren()) do
		local root = guardModel:FindFirstChild("Root")
		if root then
			local v = visuals[guardModel] or createVisual(guardModel, root)
			local down = root:GetAttribute("Down") == true
			local state = root:GetAttribute("State")
			local meter = root:GetAttribute("Meter") or 0
			local isTarget = root:GetAttribute("IsTarget") == true

			-- slide the character after the server's position so it moves smoothly
			local goal = root.CFrame * CFrame.new(0, v.yOffset, 0)
			if down then
				goal = root.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
			end
			local current = v.rig:GetPivot()
			if (current.Position - goal.Position).Magnitude > 20 then
				v.rig:PivotTo(goal)
			else
				v.rig:PivotTo(current:Lerp(goal, math.min(1, dt * 14)))
			end

			-- pick idle / walk / run from how fast the guard is really moving
			local moved = (root.Position - v.lastRootPos).Magnitude
			v.lastRootPos = root.Position
			local speedNow = (dt > 0) and (moved / dt) or 0
			v.speed = v.speed + (speedNow - v.speed) * math.min(1, dt * 6)
			local want = nil
			if not down then
				want = (v.speed > 11 and "run") or (v.speed > 1 and "walk") or "idle"
			end
			if want ~= v.anim then
				if v.anim and v.tracks[v.anim] then
					v.tracks[v.anim]:Stop(0.25)
				end
				if want and v.tracks[want] then
					v.tracks[want]:Play(0.25)
				end
				v.anim = want
			end
			if v.anim == "walk" and v.tracks.walk then
				v.tracks.walk:AdjustSpeed(math.clamp(v.speed / 9, 0.5, 1.4))
			end

			-- what the guard says when their mood changes
			if state ~= v.lastState then
				local line = nil
				if state == "chase" and not isTarget then
					line = BARKS.chase
				elseif state == "investigate" then
					line = BARKS.investigate
				elseif state == "return" then
					line = (v.lastState == "chase") and BARKS.lost or BARKS.nothing
				end
				if v.lastState ~= nil and line then
					v.bark.Text = line
					v.barkUntil = now + 2.4
				end
				v.lastState = state
			end
			if now > v.barkUntil or down then
				v.bark.Text = ""
			end

			-- marker over the head
			if down then
				v.mark.Text = ""
			elseif state == "chase" then
				v.mark.Text = "!"
				v.mark.TextColor3 = Color3.fromRGB(255, 60, 60)
			elseif meter > 0.1 or state == "investigate" then
				v.mark.Text = "?"
				v.mark.TextColor3 = Color3.fromRGB(255, 220, 80)
			elseif isTarget then
				v.mark.Text = "TARGET"
				v.mark.TextColor3 = Color3.fromRGB(255, 90, 90)
			else
				v.mark.Text = ""
			end
			v.mark.TextSize = (v.mark.Text == "TARGET") and 16 or 34

			-- vision cone: a see-through shape on the floor that stops at walls and cover
			local color = Color3.fromRGB(210, 228, 255)
			local alpha = 0.84
			if state == "chase" then
				color = Color3.fromRGB(255, 50, 50)
				alpha = 0.62
			elseif meter > 0.1 then
				color = Color3.fromRGB(255, 200, 60):Lerp(Color3.fromRGB(255, 50, 50), meter)
				alpha = 0.7
			end
			local pivot = v.rig:GetPivot()
			local center = Vector3.new(pivot.Position.X, origin.Y + 0.12, pivot.Position.Z)
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			local hidden = down or look.Magnitude < 0.1
			local eye = Vector3.new(center.X, origin.Y + 4.5, center.Z)
			local previous = nil
			for i = 0, CONE_SEGMENTS do
				local point = nil
				if not hidden then
					local angle = -HALF_ANGLE + i / CONE_SEGMENTS * HALF_ANGLE * 2
					local dir = (CFrame.Angles(0, angle, 0) * look).Unit
					local hit = workspace:Raycast(eye, dir * viewRange, rayParams)
					local length = math.max(0.3, (hit and hit.Distance or viewRange) - 0.05)
					point = center + dir * length
				end
				if i > 0 then
					local pair = v.tris[i]
					local drawn = (not hidden) and drawTriangle(center, previous, point, pair[1], pair[2])
					for k = 1, 2 do
						pair[k].Transparency = drawn and alpha or 1
						pair[k].Color = color
					end
				end
				previous = point
			end
		end
	end
end

---------------------------------------------------------------------------
-- Extra feedback: detection bar, red screen edges, footstep rings, target pointer
---------------------------------------------------------------------------
local detectBack = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.new(0, 240, 0, 8),
	BackgroundColor3 = Color3.fromRGB(14, 16, 24), BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, detectBack)
local detectFill = make("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 200, 60), BorderSizePixel = 0,
}, detectBack)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, detectFill)

local edgeGradients = {}
for _, e in ipairs({
	{ UDim2.new(0, 0, 0, 0), UDim2.new(0.2, 0, 1, 0), 0 },
	{ UDim2.new(0.8, 0, 0, 0), UDim2.new(0.2, 0, 1, 0), 180 },
	{ UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.22, 0), 90 },
	{ UDim2.new(0, 0, 0.78, 0), UDim2.new(1, 0, 0.22, 0), 270 },
}) do
	local frame = make("Frame", {
		Position = e[1], Size = e[2], BackgroundColor3 = Color3.fromRGB(255, 30, 40), BorderSizePixel = 0,
		Active = false,
	}, gui)
	local gradient = make("UIGradient", { Rotation = e[3], Transparency = NumberSequence.new(1, 1) }, frame)
	table.insert(edgeGradients, gradient)
end
local shownDanger = -1

local pointer = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 150, 0, 22), TextSize = 15, Visible = false,
	TextStrokeTransparency = 0.2,
})

local nextStepRing = 0

local function pulse(position, radius, color, time, startAlpha)
	local p = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = startAlpha,
		Size = Vector3.new(0.1, 2, 2),
		CFrame = CFrame.new(position.X, origin.Y + 0.18, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
	}, fxFolder)
	TweenService:Create(p, TweenInfo.new(time), {
		Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1,
	}):Play()
	Debris:AddItem(p, time + 0.1)
end

local function updateFeedback(active, root, isCrouched)
	-- how close the most suspicious guard is to spotting you
	local danger = 0
	local targetPos = nil
	for _, guardModel in ipairs(guardsFolder:GetChildren()) do
		local guardRoot = guardModel:FindFirstChild("Root")
		if guardRoot and not guardRoot:GetAttribute("Down") then
			local meter = guardRoot:GetAttribute("Meter") or 0
			if guardRoot:GetAttribute("State") == "chase" then
				meter = 1
			end
			danger = math.max(danger, meter)
			if guardRoot:GetAttribute("IsTarget") then
				targetPos = guardRoot.Position
			end
		end
	end
	if not active then
		danger = 0
	end
	detectBack.Visible = active and danger > 0.02
	detectFill.Size = UDim2.new(danger, 0, 1, 0)
	detectFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60):Lerp(Color3.fromRGB(255, 50, 50), danger)
	local rounded = math.floor(danger * 25 + 0.5) / 25
	if rounded ~= shownDanger then
		shownDanger = rounded
		local edge = 1 - 0.6 * rounded * rounded
		for _, gradient in ipairs(edgeGradients) do
			gradient.Transparency = NumberSequence.new(edge, 1)
		end
	end

	-- rings under your feet when your footsteps can be heard
	if active and root and not isCrouched then
		local vel = root.AssemblyLinearVelocity
		if Vector3.new(vel.X, 0, vel.Z).Magnitude > 10 and os.clock() > nextStepRing then
			nextStepRing = os.clock() + 0.45
			pulse(root.Position, Config.NOISE_RADIUS, Color3.fromRGB(230, 235, 255), 0.5, 0.86)
		end
	end

	-- arrow text at the screen edge toward the target (or the exit once the target is down)
	local goalText = "TARGET"
	if level:GetAttribute("TargetDown") == true then
		goalText = "EXIT"
		targetPos = origin + Vector3.new(Config.Level.exit[1], 3, Config.Level.exit[2])
	end
	if not (active and root and targetPos) then
		pointer.Visible = false
		return
	end
	local size = camera.ViewportSize
	local vp, onScreen = camera:WorldToViewportPoint(targetPos)
	if onScreen and vp.X > 70 and vp.X < size.X - 70 and vp.Y > 100 and vp.Y < size.Y - 130 then
		pointer.Visible = false
		return
	end
	local dx, dy = vp.X - size.X / 2, vp.Y - size.Y / 2
	if vp.Z < 0 then
		dx, dy = -dx, -dy
	end
	local scale = math.min(1, (size.X / 2 - 100) / math.max(1, math.abs(dx)), (size.Y / 2 - 140) / math.max(1, math.abs(dy)))
	pointer.Position = UDim2.new(0, size.X / 2 + dx * scale, 0, size.Y / 2 + dy * scale)
	pointer.Text = goalText .. "  " .. math.floor((targetPos - root.Position).Magnitude) .. "m"
	pointer.TextColor3 = (goalText == "EXIT") and Color3.fromRGB(110, 255, 160) or Color3.fromRGB(255, 110, 110)
	pointer.Visible = true
end

-- Returns the text for the [E] prompt, or "" if there is nothing to do here.
local function findPrompt(rootPos)
	local flat = Vector3.new(rootPos.X, 0, rootPos.Z)
	for _, guardModel in ipairs(guardsFolder:GetChildren()) do
		local root = guardModel:FindFirstChild("Root")
		if root and not root:GetAttribute("Down") and root:GetAttribute("State") ~= "chase" then
			local v = flat - Vector3.new(root.Position.X, 0, root.Position.Z)
			local d = v.Magnitude
			if d < Config.TAKEDOWN_RANGE and (d < 0.5 or root.CFrame.LookVector:Dot(v.Unit) < 0.2) then
				return "[E] Take down " .. (root:GetAttribute("GuardName") or "guard")
			end
		end
	end
	local fuse = level:FindFirstChild("FuseBox")
	if fuse and (flat - Vector3.new(fuse.Position.X, 0, fuse.Position.Z)).Magnitude < 7 then
		return "[E] Cut the power"
	end
	return ""
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local lastState = nil

RunService.RenderStepped:Connect(function(dt)
	local state = level:GetAttribute("State")
	local root = myRoot()
	-- StealthMenu sets InMenu to true while the 3D main menu is open.
	local inMenu = player:GetAttribute("InMenu") == true
	gui.Enabled = not inMenu

	if state ~= lastState then
		lastState = state
		if state == "briefing" then
			crouching = false
			results.Visible = false
			selected = {}
			refreshToolButtons()
		end
	end
	briefing.Visible = state == "briefing"

	-- Camera: looks down on the building from above and behind.
	if root and not inMenu then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = camera.FieldOfView + (50 - camera.FieldOfView) * 0.06
		local focus = Vector3.new(root.Position.X, origin.Y + 2, root.Position.Z)
		local goal = CFrame.lookAt(focus + Vector3.new(0, 54, 26), focus)
		if (camera.CFrame.Position - goal.Position).Magnitude > 150 then
			camera.CFrame = goal
		else
			camera.CFrame = camera.CFrame:Lerp(goal, 0.15)
		end
	end

	local lit = level:GetAttribute("Lit") == true
	local isCrouched = level:GetAttribute("Crouching") == true
	local viewRange = (lit and Config.VIEW_RANGE_LIT or Config.VIEW_RANGE_DARK)
		* (isCrouched and Config.CROUCH_RANGE_MULT or 1)
	updateGuards(viewRange, dt)
	updateFeedback(state == "active", root, isCrouched)

	-- HUD text
	objectiveLabel.Text = level:GetAttribute("Objective") or ""
	local active = state == "active"
	timerLabel.Visible = active
	statusLabel.Visible = active
	controlsLabel.Visible = active
	promptLabel.Visible = active
	if active then
		local startTime = level:GetAttribute("StartTime") or workspace:GetServerTimeNow()
		timerLabel.Text = formatTime(workspace:GetServerTimeNow() - startTime)
		if lit then
			statusLabel.Text = "IN THE LIGHT"
			statusLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
		else
			statusLabel.Text = "HIDDEN IN THE DARK"
			statusLabel.TextColor3 = Color3.fromRGB(110, 230, 150)
		end
		if isCrouched then
			statusLabel.Text = statusLabel.Text .. "  (crouching)"
		end
		promptLabel.Text = root and findPrompt(root.Position) or ""
	end

	for i, slot in ipairs(toolSlots) do
		local name = selected[i]
		local count = name and level:GetAttribute("Tool_" .. name)
		if active and name and count then
			slot.frame.Visible = true
			slot.name.Text = "[" .. TOOL_KEYS[i] .. "] " .. Config.Tools[name].name
			slot.count.Text = (count > 0) and (count .. " left") or "empty"
			slot.frame.BackgroundTransparency = (count > 0) and 0.12 or 0.6
		else
			slot.frame.Visible = false
		end
	end
end)

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
local hintToken = 0
local function showHint(text, seconds)
	hintToken = hintToken + 1
	local token = hintToken
	hintLabel.Text = text
	task.delay(seconds or 2.5, function()
		if hintToken == token then
			hintLabel.Text = ""
		end
	end)
end

local function ring(position, radius, color, time)
	local p = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false,
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = 0.4,
		Size = Vector3.new(0.2, 2, 2),
		CFrame = CFrame.new(position.X, origin.Y + 0.2, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
	}, fxFolder)
	TweenService:Create(p, TweenInfo.new(time), {
		Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1,
	}):Play()
	Debris:AddItem(p, time + 0.1)
end

local alertToken = 0
local fx = {}

function fx.Alert(text)
	alertToken = alertToken + 1
	local token = alertToken
	alertLabel.Text = text
	alertLabel.Visible = true
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	playSound("rbxasset://sounds/electronicpingshort.wav", 0.8)
	task.delay(1.6, function()
		if alertToken == token then
			alertLabel.Visible = false
		end
	end)
end

function fx.Hint(text)
	showHint(text)
end

function fx.Takedown(position, wasTarget)
	ring(position, wasTarget and 14 or 7, Color3.fromRGB(255, 255, 255), 0.4)
	playSound("rbxasset://sounds/swordslash.wav", 0.6)
	if wasTarget then
		-- quick zoom punch for the big moment
		camera.FieldOfView = 38
		showHint("TARGET DOWN. Get to the exit.", 4)
	end
end

function fx.Noise(position, radius)
	ring(position, radius, Color3.fromRGB(255, 220, 80), 0.8)
	playSound("rbxasset://sounds/clickfast.wav", 0.8)
end

function fx.Smoke(position, radius, time)
	local p = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false,
		Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(150, 155, 165), Transparency = 1, Size = Vector3.new(2, 2, 2),
		Position = Vector3.new(position.X, origin.Y + 2, position.Z),
	}, fxFolder)
	TweenService:Create(p, TweenInfo.new(0.5), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2), Transparency = 0.35,
	}):Play()
	task.delay(time - 1, function()
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(1), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(p, time + 0.2)
end

function fx.Dart(from, to)
	local length = (to - from).Magnitude
	local p = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CastShadow = false,
		Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 255, 200),
		Size = Vector3.new(0.15, 0.15, length), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
	}, fxFolder)
	TweenService:Create(p, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.4)
end

function fx.PowerCut(seconds)
	showHint("Power is out for " .. seconds .. " seconds.", 4)
	playSound("rbxasset://sounds/switch.wav", 0.8)
end

FxRemote.OnClientEvent:Connect(function(name, ...)
	local handler = fx[name]
	if handler then
		handler(...)
	end
end)
