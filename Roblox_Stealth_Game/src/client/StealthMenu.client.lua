-- StealthMenu (LocalScript, goes in StarterPlayer > StarterPlayerScripts)
-- The 3D main menu. The camera starts on a copy of your character standing at the
-- start of a dark hallway. Picking a menu option glides the camera down the hallway
-- to a board on the wall for that menu.
--
-- This script and StealthClient talk through one flag on the player called "InMenu".
-- While it is true, StealthClient hides the game HUD and leaves the camera alone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
player:SetAttribute("InMenu", true)

local Config = require(ReplicatedStorage:WaitForChild("StealthConfig"))
local level = workspace:WaitForChild("Level_" .. player.UserId)
local base = level:GetAttribute("Origin") + Vector3.new(0, 300, 0) -- the menu hallway floats above the building

local FONT = Enum.Font.GothamBold
local FONT_LIGHT = Enum.Font.Gotham
local RED = Color3.fromRGB(215, 45, 55)
local HALL_LENGTH = 142
local CHARACTER_SPOT = Vector3.new(-2.5, 0, 0)

local function make(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function S(x, y, z)
	return base + Vector3.new(x, y, z)
end

---------------------------------------------------------------------------
-- Building the hallway (only on this player's screen)
---------------------------------------------------------------------------
local scene = Instance.new("Model")
scene.Name = "MenuScene"

local function block(name, size, position, color, material, extra)
	local props = {
		Name = name, Anchored = true, Size = size, Position = position, Color = color,
		Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
	}
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return make("Part", props, scene)
end

local midZ = -60
local wallColor = Color3.fromRGB(26, 28, 38)
block("Floor", Vector3.new(16, 1, HALL_LENGTH), S(0, -0.5, midZ), Color3.fromRGB(18, 18, 24),
	Enum.Material.SmoothPlastic, { Reflectance = 0.25 })
block("Ceiling", Vector3.new(18, 1, HALL_LENGTH), S(0, 12.5, midZ), Color3.fromRGB(14, 14, 18))
block("LeftWall", Vector3.new(1, 13, HALL_LENGTH), S(-8.5, 6, midZ), wallColor, Enum.Material.Concrete)
block("RightWall", Vector3.new(1, 13, HALL_LENGTH), S(8.5, 6, midZ), wallColor, Enum.Material.Concrete)
block("EndWall", Vector3.new(18, 13, 1), S(0, 6, midZ - HALL_LENGTH / 2 - 0.5), wallColor, Enum.Material.Concrete)
block("BackWall", Vector3.new(18, 13, 1), S(0, 6, midZ + HALL_LENGTH / 2 + 0.5), wallColor, Enum.Material.Concrete)

-- red light strips along the floor
for _, x in ipairs({ -7.8, 7.8 }) do
	block("FloorStrip", Vector3.new(0.2, 0.1, HALL_LENGTH), S(x, 0.06, midZ), RED, Enum.Material.Neon,
		{ CastShadow = false })
end
-- dim ceiling lights down the hall
for z = -12, -124, -24 do
	local bar = block("CeilingLight", Vector3.new(6, 0.2, 0.8), S(0, 11.9, z), Color3.fromRGB(170, 185, 225),
		Enum.Material.Neon, { CastShadow = false })
	make("PointLight", { Range = 18, Brightness = 0.5, Color = Color3.fromRGB(170, 185, 225) }, bar)
end
-- spotlight on the character, plus a red glow behind them
local spotHolder = block("CharacterSpot", Vector3.new(1, 0.2, 1), S(CHARACTER_SPOT.X, 11.8, 1.5),
	Color3.fromRGB(255, 240, 220), Enum.Material.Neon, { CastShadow = false })
make("SpotLight", {
	Face = Enum.NormalId.Bottom, Range = 22, Brightness = 5, Angle = 55,
	Color = Color3.fromRGB(255, 236, 214), Shadows = true,
}, spotHolder)
local rim = block("RimGlow", Vector3.new(0.2, 0.2, 0.2), S(CHARACTER_SPOT.X, 4.5, -5), RED,
	Enum.Material.Neon, { Transparency = 1 })
make("PointLight", { Range = 12, Brightness = 2.2, Color = RED }, rim)

---------------------------------------------------------------------------
-- Boards on the walls (one per menu)
---------------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")

local function text(props, parent)
	local baseProps = {
		BackgroundTransparency = 1, Font = FONT, TextColor3 = Color3.new(1, 1, 1), TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, Text = "",
	}
	for k, v in pairs(props) do
		baseProps[k] = v
	end
	return make("TextLabel", baseProps, parent)
end

-- side: "left", "right" or "end". Returns the frame to put content in, and the camera view for it.
local function makeBoard(title, side, z)
	local part, face, view
	if side == "left" then
		part = block("Board", Vector3.new(0.3, 7, 12), S(-7.85, 5.5, z), Color3.fromRGB(12, 13, 20))
		face = Enum.NormalId.Right
		view = CFrame.lookAt(S(3.5, 5.5, z), S(-7.85, 5.5, z))
		block("BoardTrim", Vector3.new(0.3, 0.15, 12), S(-7.8, 1.9, z), RED, Enum.Material.Neon, { CastShadow = false })
	elseif side == "right" then
		part = block("Board", Vector3.new(0.3, 7, 12), S(7.85, 5.5, z), Color3.fromRGB(12, 13, 20))
		face = Enum.NormalId.Left
		view = CFrame.lookAt(S(-3.5, 5.5, z), S(7.85, 5.5, z))
		block("BoardTrim", Vector3.new(0.3, 0.15, 12), S(7.8, 1.9, z), RED, Enum.Material.Neon, { CastShadow = false })
	else
		part = block("Board", Vector3.new(12, 7, 0.3), S(0, 5.5, z), Color3.fromRGB(12, 13, 20))
		face = Enum.NormalId.Back
		view = CFrame.lookAt(S(0, 5.5, z + 13.5), S(0, 5.5, z))
		block("BoardTrim", Vector3.new(12, 0.15, 0.3), S(0, 1.9, z + 0.05), RED, Enum.Material.Neon, { CastShadow = false })
	end
	local surface = make("SurfaceGui", {
		Name = "Menu_" .. title, Adornee = part, Face = face, LightInfluence = 0, ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50,
	}, playerGui)
	local frame = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1 }, surface)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 28), PaddingRight = UDim.new(0, 28),
		PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20),
	}, frame)
	text({ Size = UDim2.new(1, 0, 0, 40), TextSize = 38, TextColor3 = RED, Text = title }, frame)
	return frame, view, surface
end

local views = {
	main = CFrame.lookAt(S(2.5, 4.4, 8.5), S(-1.5, 4, 0)),
}
local surfaces = {}

-- CONTRACTS
local contractsFrame
contractsFrame, views.contracts, surfaces[1] = makeBoard("CONTRACTS", "left", -30)
local contractCards = {
	{ Config.Mission.name, "Target: " .. Config.Mission.target .. "\nOne building. Get in, take him out, get out.", true },
	{ "THE NIGHTCLUB", "Locked. Coming soon.", false },
	{ "THE CARGO SHIP", "Locked. Coming soon.", false },
}
for i, card in ipairs(contractCards) do
	local box = make("Frame", {
		Position = UDim2.new((i - 1) / 3, 4, 0, 60), Size = UDim2.new(1 / 3, -8, 1, -60),
		BackgroundColor3 = card[3] and Color3.fromRGB(46, 20, 26) or Color3.fromRGB(24, 26, 36),
		BorderSizePixel = 0,
	}, contractsFrame)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
	make("UIStroke", { Color = card[3] and RED or Color3.fromRGB(60, 64, 84), Thickness = 2 }, box)
	text({
		Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(1, -24, 0, 54), TextSize = 22,
		TextColor3 = card[3] and Color3.new(1, 1, 1) or Color3.fromRGB(120, 124, 140), Text = card[1],
	}, box)
	text({
		Position = UDim2.new(0, 12, 0, 70), Size = UDim2.new(1, -24, 1, -82), Font = FONT_LIGHT, TextSize = 16,
		TextColor3 = card[3] and Color3.fromRGB(220, 222, 235) or Color3.fromRGB(120, 124, 140), Text = card[2],
	}, box)
end

-- ARMORY
local armoryFrame
armoryFrame, views.armory, surfaces[2] = makeBoard("ARMORY", "right", -60)
for i, name in ipairs(Config.ToolOrder) do
	local def = Config.Tools[name]
	local y = 56 + (i - 1) * 58
	text({ Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, 24), Text = def.name .. "   x" .. def.uses }, armoryFrame)
	text({
		Position = UDim2.new(0, 0, 0, y + 25), Size = UDim2.new(1, 0, 0, 30), Font = FONT_LIGHT, TextSize = 16,
		TextColor3 = Color3.fromRGB(205, 208, 222), Text = def.description,
	}, armoryFrame)
end
text({
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 20),
	Font = FONT_LIGHT, TextSize = 15, TextColor3 = Color3.fromRGB(150, 154, 170),
	Text = "You pick " .. Config.LOADOUT_SIZE .. " of these at the start of each contract.",
}, armoryFrame)

-- HOW TO PLAY
local howFrame
howFrame, views.howto, surfaces[3] = makeBoard("HOW TO PLAY", "left", -90)
text({
	Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 1, -56), Font = FONT_LIGHT, TextSize = 18,
	TextColor3 = Color3.fromRGB(220, 222, 235), LineHeight = 1.25,
	Text = "WASD  move          C  crouch          E  takedown / use          Q, R  tools\n\n"
		.. "The lines on the floor show what a guard can see.\n"
		.. "Stay out of lamp light. In the dark they have to be close to see you.\n"
		.. "Walking near a guard makes noise. Crouching is silent.\n"
		.. "Take guards down from behind. Never from the front.\n"
		.. "?  means a guard is getting suspicious.   !  means run.\n"
		.. "Take out the target, then get back to the exit.",
}, howFrame)

-- RECORDS
local recordsFrame
recordsFrame, views.records, surfaces[4] = makeBoard("RECORDS", "end", midZ - HALL_LENGTH / 2 + 0.2)
text({
	Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(0.5, 0, 0, 24), Font = FONT_LIGHT, TextSize = 18,
	TextColor3 = Color3.fromRGB(205, 208, 222), Text = Config.Mission.name .. "  best rank",
}, recordsFrame)
local bestRankLabel = text({
	Position = UDim2.new(0, 0, 0, 84), Size = UDim2.new(0.5, 0, 0, 190), TextSize = 180,
	TextColor3 = Color3.fromRGB(255, 200, 60), Text = "-",
}, recordsFrame)
local bestScoreLabel = text({
	Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.new(0.5, 0, 0, 160), Font = FONT_LIGHT, TextSize = 20,
	TextColor3 = Color3.fromRGB(220, 222, 235), Text = "",
}, recordsFrame)

local function refreshRecords()
	local rank = player:GetAttribute("BestRank")
	local score = player:GetAttribute("BestScore")
	bestRankLabel.Text = rank or "-"
	if score then
		bestScoreLabel.Text = "Best score: " .. score .. " / 100\n\nS rank needs 95 or more.\nDon't get spotted and finish under "
			.. math.floor(Config.PAR_TIME / 60) .. " minutes."
	else
		bestScoreLabel.Text = "No contract finished yet.\n\nComplete one to set a record."
	end
end
refreshRecords()
player:GetAttributeChangedSignal("BestRank"):Connect(refreshRecords)
player:GetAttributeChangedSignal("BestScore"):Connect(refreshRecords)

---------------------------------------------------------------------------
-- The character standing at the start of the hallway
---------------------------------------------------------------------------
local menuCharacter = nil

local function buildMenuCharacter()
	local char = player.Character or player.CharacterAdded:Wait()
	-- wait a little for clothes and accessories to load so the copy isn't a grey dummy
	local waited = 0
	while not player:HasAppearanceLoaded() and waited < 6 do
		waited = waited + task.wait(0.2)
	end
	char = player.Character or char
	local sourceHum = char:FindFirstChildOfClass("Humanoid")
	if not sourceHum or not char:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- remember the idle animation before the scripts get stripped out of the copy
	local idleAnimation = nil
	local animate = char:FindFirstChild("Animate")
	local idleFolder = animate and animate:FindFirstChild("idle")
	if idleFolder then
		idleAnimation = idleFolder:FindFirstChildOfClass("Animation")
	end

	char.Archivable = true
	local copy = char:Clone()
	char.Archivable = false
	if not copy then
		return
	end
	copy.Name = "MenuCharacter"
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	local root = copy:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	root.Anchored = true

	local height = hum.HipHeight + root.Size.Y / 2
	if hum.RigType == Enum.HumanoidRigType.R6 then
		height = height + 2
	end
	local pos = S(CHARACTER_SPOT.X, height, CHARACTER_SPOT.Z)
	-- stands facing the camera, turned a little toward it
	copy:PivotTo(CFrame.lookAt(pos, Vector3.new(views.main.Position.X, pos.Y, views.main.Position.Z)))

	if menuCharacter then
		menuCharacter:Destroy()
	end
	menuCharacter = copy
	copy.Parent = scene

	pcall(function()
		if idleAnimation then
			local animator = hum:FindFirstChildOfClass("Animator") or make("Animator", {}, hum)
			local track = animator:LoadAnimation(idleAnimation)
			track.Looped = true
			track:Play()
		end
	end)
end

---------------------------------------------------------------------------
-- Screen buttons
---------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "StealthMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
}, playerGui)

local mainPanel = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0),
	Size = UDim2.new(0, 420, 0, 420), BackgroundTransparency = 1,
}, gui)
make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, Font = FONT, TextSize = 50,
	TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, Text = "SILENT CONTRACT",
	TextStrokeTransparency = 0.5,
}, mainPanel)
make("TextLabel", {
	Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
	Font = FONT_LIGHT, TextSize = 18, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Right,
	Text = "get in.  get it done.  get out.",
}, mainPanel)

local stationPanel = make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false }, gui)
local backButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 40, 1, -40), Size = UDim2.new(0, 150, 0, 44),
	BackgroundColor3 = Color3.fromRGB(26, 28, 40), BorderSizePixel = 0, Font = FONT, TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1), Text = "<  BACK",
}, stationPanel)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, backButton)
local acceptButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(0, 300, 0, 52),
	BackgroundColor3 = RED, BorderSizePixel = 0, Font = FONT, TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1), Text = "ACCEPT CONTRACT", Visible = false,
}, stationPanel)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, acceptButton)

local fade = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
	BorderSizePixel = 0, ZIndex = 20,
}, gui)

---------------------------------------------------------------------------
-- Moving the camera between menus
---------------------------------------------------------------------------
local current = "main"
local move = nil -- { from, to, start, duration } while the camera is travelling
local cameraBase = views.main
local busy = false

local function goTo(name)
	if busy or name == current or not views[name] then
		return
	end
	current = name
	local target = views[name]
	local distance = (cameraBase.Position - target.Position).Magnitude
	move = { from = cameraBase, to = target, start = os.clock(), duration = math.clamp(distance / 45, 1.1, 2.6) }
	mainPanel.Visible = name == "main"
	stationPanel.Visible = name ~= "main"
	acceptButton.Visible = name == "contracts"
end

local function startGame()
	if busy then
		return
	end
	busy = true
	TweenService:Create(fade, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
	task.wait(0.45)
	player:SetAttribute("InMenu", false)
	mainPanel.Visible = false
	stationPanel.Visible = false
	scene.Parent = nil
	for _, surface in ipairs(surfaces) do
		surface.Enabled = false
	end
	task.wait(0.15)
	TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	busy = false
end

local function showMenu()
	current = "main"
	move = nil
	cameraBase = views.main
	scene.Parent = workspace
	for _, surface in ipairs(surfaces) do
		surface.Enabled = true
	end
	mainPanel.Visible = true
	stationPanel.Visible = false
	refreshRecords()
	fade.BackgroundTransparency = 0
	TweenService:Create(fade, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

-- main menu buttons
local menuItems = {
	{ "PLAY", function() goTo("contracts") end },
	{ "ARMORY", function() goTo("armory") end },
	{ "HOW TO PLAY", function() goTo("howto") end },
	{ "RECORDS", function() goTo("records") end },
}
for i, item in ipairs(menuItems) do
	local button = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 110 + (i - 1) * 58),
		Size = UDim2.new(0, 300, 0, 48), BackgroundColor3 = Color3.fromRGB(16, 17, 26),
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Font = FONT, TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, Text = item[1] .. "   ",
		AutoButtonColor = false,
	}, mainPanel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	local bar = make("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = RED, BorderSizePixel = 0, BackgroundTransparency = 1,
	}, button)
	button.MouseEnter:Connect(function()
		bar.BackgroundTransparency = 0
		TweenService:Create(button, TweenInfo.new(0.12), {
			Size = UDim2.new(0, 330, 0, 48), BackgroundTransparency = 0.1,
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		bar.BackgroundTransparency = 1
		TweenService:Create(button, TweenInfo.new(0.12), {
			Size = UDim2.new(0, 300, 0, 48), BackgroundTransparency = 0.35,
		}):Play()
	end)
	button.Activated:Connect(item[2])
end
backButton.Activated:Connect(function()
	goTo("main")
end)
acceptButton.Activated:Connect(startGame)

RunService.RenderStepped:Connect(function()
	if player:GetAttribute("InMenu") == false then
		return
	end
	if move then
		local t = math.clamp((os.clock() - move.start) / move.duration, 0, 1)
		local eased = t * t * (3 - 2 * t) -- slow start, slow stop
		cameraBase = move.from:Lerp(move.to, eased)
		if t >= 1 then
			move = nil
		end
	end
	-- the view drifts a little with the mouse so the scene feels 3D
	local offsetX, offsetY = 0, 0
	if UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		local size = camera.ViewportSize
		offsetX = (mouse.X / math.max(1, size.X) - 0.5) * 2
		offsetY = (mouse.Y / math.max(1, size.Y) - 0.5) * 2
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60
	camera.CFrame = cameraBase * CFrame.new(offsetX * 0.35, -offsetY * 0.2, 0)
		* CFrame.Angles(math.rad(-offsetY * 1.2), math.rad(-offsetX * 1.8), 0)
end)

-- StealthClient sets InMenu back to true when the player presses MAIN MENU on the results screen.
player:GetAttributeChangedSignal("InMenu"):Connect(function()
	if player:GetAttribute("InMenu") == true and scene.Parent == nil then
		showMenu()
	end
end)

scene.Parent = workspace
task.spawn(buildMenuCharacter)
