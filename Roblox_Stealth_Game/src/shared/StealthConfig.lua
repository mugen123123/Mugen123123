-- StealthConfig (ModuleScript, goes in ReplicatedStorage)
-- Every number and the whole test level live here, so this is the file to edit
-- when you want to tune the stealth or change the building.

local Config = {}

-- World -----------------------------------------------------------------
Config.LEVEL_SPACING = 400 -- every player gets their own copy of the building, this far apart
Config.BASE_HEIGHT = 50
Config.WALL_HEIGHT = 7
Config.COVER_HEIGHT = 5.5

-- Player ----------------------------------------------------------------
Config.WALK_SPEED = 16
Config.CROUCH_SPEED = 8

-- Guard senses ------------------------------------------------------------
Config.VIEW_HALF_ANGLE = 35     -- degrees to each side of where a guard is looking
Config.VIEW_RANGE_LIT = 36      -- how far guards see you when you stand in light
Config.VIEW_RANGE_DARK = 13     -- how far they see you in the dark
Config.CROUCH_RANGE_MULT = 0.8  -- crouching shrinks both ranges
Config.DETECT_TIME_NEAR = 0.35  -- seconds to get spotted when you are right next to a guard
Config.DETECT_TIME_FAR = 1.5    -- seconds at the edge of their view
Config.DETECT_DECAY = 0.5       -- how fast the meter drains when they lose you
Config.NOISE_RADIUS = 13        -- walking (not crouching) this close gets a guard to come look
Config.BODY_SIGHT_RANGE = 22
Config.TAKEDOWN_RANGE = 5.5
Config.CATCH_RANGE = 3.5
Config.CHASE_GIVE_UP_TIME = 6
Config.GUARD_SPEED = { patrol = 7, investigate = 10, chase = 15 }

-- Lights ------------------------------------------------------------------
Config.LAMP_RADIUS = 16
Config.POWER_CUT_TIME = 15
Config.FUSE_BOX_COOLDOWN = 40

-- Grading -----------------------------------------------------------------
Config.PAR_TIME = 180 -- seconds. Slower than this starts costing points.

-- Tools -------------------------------------------------------------------
Config.LOADOUT_SIZE = 2
Config.ToolOrder = { "NoiseMaker", "Smoke", "Dart", "PowerCutter" }
Config.Tools = {
	NoiseMaker = {
		name = "Noise Maker", uses = 3, range = 45, hearRadius = 30,
		description = "Throw it where you aim. Guards nearby walk over to check it out.",
	},
	Smoke = {
		name = "Smoke Bomb", uses = 2, radius = 9, time = 8,
		description = "Drops smoke where you stand. Guards can't see through it.",
	},
	Dart = {
		name = "Sleep Dart", uses = 2, range = 45, aimSlack = 10,
		description = "Aim at a guard to knock them out from far away.",
	},
	PowerCutter = {
		name = "Power Cutter", uses = 1,
		description = "Kills every light in the building for 15 seconds.",
	},
}

-- Mission text ------------------------------------------------------------
Config.Mission = {
	name = "THE PENTHOUSE",
	target = "Victor Crane",
	briefing = "Crane works late in his office (top left). Every few minutes he walks through "
		.. "the lounge to the balcony for a break. The balcony is dark and nobody else goes out there. "
		.. "The fuse box is in the security room (bottom right). Get out through the storage room where you start.",
}

-- Test level --------------------------------------------------------------
-- Everything is measured in studs from the middle of the building. x is left/right, z is up/down
-- on screen. The building is 120 wide (x -60..60) and 80 deep (z -40..40).
--
--   +----------------------+----------------------+---------+
--   | OFFICE (target)      | LOUNGE               | BALCONY |
--   +------  --------------+-------  -------------+---  ----+   z = -10
--   | HALLWAY                                               |
--   +-------  -------+-----------  ----------+-----  -------+   z = 6
--   | STORAGE        | LOBBY                 | SECURITY      |
--   | (start, exit)  |                       | (fuse box)    |
--   +----------------+-----------------------+---------------+
Config.Level = {
	halfWidth = 60,
	halfDepth = 40,

	-- axis "x" = a wall running left/right at z = fixed. axis "z" = a wall running up/down at x = fixed.
	-- gaps are the doorways.
	walls = {
		{ axis = "x", fixed = -40, from = -60, to = 60 },
		{ axis = "x", fixed = 40, from = -60, to = 60 },
		{ axis = "z", fixed = -60, from = -40, to = 40 },
		{ axis = "z", fixed = 60, from = -40, to = 40 },
		{ axis = "x", fixed = -10, from = -60, to = 60, gaps = { { -44, -36 }, { 8, 16 }, { 44, 52 } } },
		{ axis = "x", fixed = 6, from = -60, to = 60, gaps = { { -46, -38 }, { -4, 4 }, { 38, 46 } } },
		{ axis = "z", fixed = -10, from = -40, to = -10, gaps = { { -30, -22 } } },
		{ axis = "z", fixed = 35, from = -40, to = -10, gaps = { { -28, -20 } } },
		{ axis = "z", fixed = -25, from = 6, to = 40, gaps = { { 20, 28 } } },
		{ axis = "z", fixed = 25, from = 6, to = 40, gaps = { { 20, 28 } } },
	},

	-- Things to hide behind: { x, z, sizeX, sizeZ }
	cover = {
		{ -50, 18, 6, 6 }, { -35, 34, 8, 4 },                      -- storage crates
		{ 0, 26, 14, 3 }, { -14, 12, 3, 3 }, { 14, 12, 3, 3 }, { -18, 34, 8, 3 }, -- lobby
		{ -20, -8, 4, 2 }, { 22, 4, 4, 2 }, { -52, 4, 4, 2 },      -- hallway planters
		{ 50, 12, 10, 3 }, { 30, 36, 4, 6 },                       -- security
		{ 10, -36, 16, 3 }, { 5, -20, 8, 3 }, { 25, -19, 3, 6 },   -- lounge
		{ -45, -35, 10, 3 }, { -20, -38, 10, 2 }, { -56, -20, 3, 8 }, -- office
		{ 56, -34, 3, 6 }, { 40, -36, 6, 3 },                      -- balcony
	},

	-- Lamps: { x, z }. Anything within LAMP_RADIUS of one counts as standing in light.
	lamps = {
		{ -30, -2 }, { 15, -2 }, { 50, -2 }, -- hallway
		{ 0, 18 },                           -- lobby
		{ 42, 24 },                          -- security
		{ 14, -26 },                         -- lounge
		{ -42, -26 },                        -- office
	},

	start = { -46, 30 },
	exit = { -55, 36 },
	fuseBox = { 58, 36 },

	-- Patrol points: { x, z, secondsToWaitThere }.
	-- loop = true walks the points in a circle. Otherwise they walk to the end and back.
	guards = {
		{ name = "Hall Guard", points = { { -52, -2, 2 }, { 52, -2, 2 } } },
		{ name = "Lobby Guard", loop = true, points = { { -15, 16, 1 }, { 15, 16, 1 }, { 15, 31, 1 }, { -15, 31, 1 } } },
		{ name = "Security Guard", points = { { 32, 16, 4 }, { 52, 22, 4 } } },
		{ name = "Lounge Guard", loop = true, points = { { -4, -32, 1 }, { 30, -32, 2 }, { 30, -13.5, 1 }, { -4, -13.5, 2 } } },
		{ name = "Bodyguard", points = { { -52, -15, 3 }, { -22, -15, 3 } } },
		{
			name = "Victor Crane", target = true,
			points = { { -45, -29, 10 }, { -14, -26 }, { -6, -26 }, { 12, -27, 4 }, { 31, -24 }, { 40, -24 }, { 48, -30, 12 } },
		},
	},
}

return Config
