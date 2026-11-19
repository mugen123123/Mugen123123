-- FightConfig (ModuleScript, goes in ReplicatedStorage)
-- All the numbers for the game live here, so this is the file to edit
-- when you want to balance fighters or add moves.

local Config = {}

-- Arena -------------------------------------------------------------------
Config.ARENA_CENTER = Vector3.new(0, 100, 0) -- top of the arena floor
Config.ARENA_HALF_WIDTH = 45                 -- how far fighters can go left/right
Config.START_OFFSET = 10                     -- how far from the middle each fighter starts
Config.LOBBY_POSITION = Vector3.new(0, 110, 80)

-- Match rules ---------------------------------------------------------------
Config.ROUND_TIME = 60    -- seconds per round
Config.ROUNDS_TO_WIN = 2  -- best of 3
Config.MAX_METER = 300    -- 3 bars
Config.METER_BAR = 100
Config.CHIP_DAMAGE = 0.15 -- part of the damage that still goes through a block
Config.MAX_LIGHT_CHAIN = 3

-- Fighters ------------------------------------------------------------------
-- damageMult multiplies every move's damage. projectileSpeed/Size change the special.
Config.FighterOrder = { "Volt", "Brakka", "Wisp" }

Config.Fighters = {
	Volt = {
		name = "Volt",
		description = "Balanced. Fast spark shot.",
		color = Color3.fromRGB(255, 221, 51),
		maxHp = 1000,
		speed = 17,
		damageMult = 1,
		projectileSpeed = 70,
		projectileSize = 2,
	},
	Brakka = {
		name = "Brakka",
		description = "Slow but hits hard. Big slow boulder.",
		color = Color3.fromRGB(255, 110, 60),
		maxHp = 1150,
		speed = 14,
		damageMult = 1.15,
		projectileSpeed = 42,
		projectileSize = 3.2,
	},
	Wisp = {
		name = "Wisp",
		description = "Very fast, lower health. Quick gust.",
		color = Color3.fromRGB(90, 230, 255),
		maxHp = 900,
		speed = 21,
		damageMult = 0.9,
		projectileSpeed = 90,
		projectileSize = 1.6,
	},
}

Config.DEFAULT_FIGHTER = "Volt"

-- Moves ---------------------------------------------------------------------
-- rank:      a move can cancel into a higher rank move when it hits (that's how combos work)
-- startup:   seconds before the move can hit
-- recovery:  seconds you are stuck after the move comes out
-- range:     how close the other fighter has to be (studs)
-- hitstun:   how long the other fighter is stunned when hit
-- blockstun: how long they are stuck when they block it
-- knockX/Y:  knockback
-- cost:      super meter used
Config.Moves = {
	Light = {
		rank = 1, startup = 0.10, recovery = 0.22, range = 5.5, damage = 40,
		hitstun = 0.40, blockstun = 0.18, knockX = 6, knockY = 0, meterGain = 8, cost = 0,
	},
	Heavy = {
		rank = 2, startup = 0.24, recovery = 0.40, range = 6.5, damage = 90,
		hitstun = 0.60, blockstun = 0.30, knockX = 20, knockY = 22, meterGain = 14, cost = 0,
	},
	Grab = {
		rank = 2, startup = 0.28, recovery = 0.50, range = 4.5, damage = 110,
		hitstun = 0.80, blockstun = 0, knockX = 28, knockY = 26, meterGain = 12, cost = 0,
		unblockable = true, groundOnly = true,
	},
	Special = {
		rank = 3, startup = 0.28, recovery = 0.45, damage = 80,
		hitstun = 0.50, blockstun = 0.30, knockX = 14, knockY = 0, meterGain = 10, cost = 0,
		projectile = true, cooldown = 1.2, power = 1,
	},
	Enhanced = {
		rank = 4, startup = 0.25, recovery = 0.45, damage = 150,
		hitstun = 0.70, blockstun = 0.35, knockX = 24, knockY = 20, meterGain = 0, cost = 100,
		projectile = true, cooldown = 1.2, power = 2, sizeMult = 1.6, speedMult = 1.25,
	},
	Super = {
		rank = 5, startup = 0.40, recovery = 0.70, range = 11, damage = 320,
		hitstun = 1.00, blockstun = 0.50, knockX = 45, knockY = 38, meterGain = 0, cost = 300,
		armor = true,
	},
}

-- Keyboard / gamepad keys (the client reads these)
Config.Controls = {
	{ action = "Light",    title = "Light",   key = Enum.KeyCode.J, pad = Enum.KeyCode.ButtonX },
	{ action = "Heavy",    title = "Heavy",   key = Enum.KeyCode.K, pad = Enum.KeyCode.ButtonY },
	{ action = "Grab",     title = "Grab",    key = Enum.KeyCode.H, pad = Enum.KeyCode.ButtonB },
	{ action = "Special",  title = "Special", key = Enum.KeyCode.L, pad = Enum.KeyCode.ButtonR1 },
	{ action = "Enhanced", title = "EX",      key = Enum.KeyCode.U, pad = Enum.KeyCode.ButtonR2 },
	{ action = "Super",    title = "SUPER",   key = Enum.KeyCode.I, pad = Enum.KeyCode.ButtonL2 },
	{ action = "Block",    title = "Block",   key = Enum.KeyCode.F, pad = Enum.KeyCode.ButtonL1 },
}

return Config
