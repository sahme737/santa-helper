--!strict
-- Christmas Playground: every tunable gameplay number lives here.
-- NOTE: this module replicates to clients. Nothing secret belongs here, and the
-- server never trusts a client-reported value derived from this file.

local Config = {}

Config.GAME_NAME = "Christmas Playground"
Config.DATASTORE_NAME = "SantasHelper_Profiles_v1"
Config.LEADERBOARD_DELIVERED = "SantasHelper_Delivered_2026"
Config.LEADERBOARD_CHEER = "SantasHelper_Cheer_2026"
Config.LEADERBOARD_STARS = "SantasHelper_Stars_2026"

Config.AUTOSAVE_INTERVAL = 60
Config.STATE_PUSH_RATE = 0.25 -- seconds between client state pushes (max)
Config.MAX_PLOTS = 6

-- Holiday event window (UTC). Advent doors open Dec 1-25, the event ends Dec 31.
Config.EVENT = {
	YEAR = 2026,
	END_TIME = 1798761599, -- 2026-12-31 23:59:59 UTC
	ADVENT_START = 1796083200, -- 2026-12-01 00:00:00 UTC
	ADVENT_MONTH = 12,
	ADVENT_LAST_DAY = 25,
}

-------------------------------------------------------------------------------
-- Workshop: toy machines (bought in order on the plot's buy pads)
-------------------------------------------------------------------------------
export type MachineDef = {
	id: string,
	name: string,
	toy: string,
	cost: number,
	value: number, -- coins per toy at level 1
	interval: number, -- seconds per toy
	color: Color3,
}

Config.MACHINES = {
	{
		id = "M1",
		name = "Teddy Bear Bench",
		toy = "Teddy",
		cost = 0,
		value = 10,
		interval = 2,
		color = Color3.fromRGB(196, 132, 84),
	},
	{
		id = "M2",
		name = "Toy Train Press",
		toy = "Train",
		cost = 150,
		value = 30,
		interval = 2,
		color = Color3.fromRGB(220, 60, 60),
	},
	{
		id = "M3",
		name = "Rocking Horse Lathe",
		toy = "Horse",
		cost = 1000,
		value = 90,
		interval = 2,
		color = Color3.fromRGB(240, 180, 70),
	},
	{
		id = "M4",
		name = "Doll House Builder",
		toy = "House",
		cost = 5500,
		value = 280,
		interval = 2,
		color = Color3.fromRGB(240, 130, 190),
	},
	{
		id = "M5",
		name = "Robot Assembler",
		toy = "Robot",
		cost = 28000,
		value = 850,
		interval = 2,
		color = Color3.fromRGB(120, 170, 230),
	},
	{
		id = "M6",
		name = "Game Console Factory",
		toy = "Console",
		cost = 140000,
		value = 2600,
		interval = 2,
		color = Color3.fromRGB(130, 90, 210),
	},
	{
		id = "M7",
		name = "Rocket Ship Forge",
		toy = "Rocket",
		cost = 700000,
		value = 8000,
		interval = 2,
		color = Color3.fromRGB(70, 200, 160),
	},
	{
		id = "M8",
		name = "Magic Snow Globe Machine",
		toy = "Globe",
		cost = 3500000,
		value = 25000,
		interval = 2,
		color = Color3.fromRGB(150, 230, 255),
	},
} :: { MachineDef }

Config.MACHINE_MAX_LEVEL = 25
Config.MACHINE_LEVEL_VALUE_BONUS = 0.3 -- +30% toy value per level above 1
Config.MACHINE_UPGRADE_GROWTH = 1.55

-------------------------------------------------------------------------------
-- Workshop decorations: each one adds Festive Cheer (+% income)
-------------------------------------------------------------------------------
export type DecorDef =
	{ id: string, name: string, cost: number, bonus: number, unlockAfter: number }

Config.DECOR = {
	{ id = "D1", name = "Candy Cane Fence", cost = 300, bonus = 0.05, unlockAfter = 1 },
	{ id = "D2", name = "Jolly Snowman", cost = 1200, bonus = 0.05, unlockAfter = 2 },
	{ id = "D3", name = "Twinkle Light Posts", cost = 3000, bonus = 0.05, unlockAfter = 3 },
	{ id = "D4", name = "Workshop Christmas Tree", cost = 8000, bonus = 0.05, unlockAfter = 4 },
	{ id = "D5", name = "Gingerbread House", cost = 25000, bonus = 0.05, unlockAfter = 5 },
	{ id = "D6", name = "Ice Sculpture", cost = 80000, bonus = 0.05, unlockAfter = 6 },
	{ id = "D7", name = "Giant Ornament", cost = 250000, bonus = 0.05, unlockAfter = 7 },
	{ id = "D8", name = "North Star Arch", cost = 800000, bonus = 0.05, unlockAfter = 8 },
} :: { DecorDef }

-------------------------------------------------------------------------------
-- Elves, sack, sleigh upgrades
-------------------------------------------------------------------------------
Config.ELVES = {
	MAX = 10,
	BASE_COST = 500,
	GROWTH = 2.4,
	BONUS_EACH = 0.1, -- +10% production per elf
}

-- Wrapping presents by hand at the wrapping table. Elves do it for you.
Config.WRAP = {
	COOLDOWN = 1.5, -- seconds between wraps the server accepts
	INCOME_SECONDS = 6, -- one wrap is worth this many seconds of production
	MIN_VALUE = 25,
	REACH = 20, -- studs from the table
}

-- The snowball fight arena beside the plaza. Free for everyone from the
-- first minute; nothing is earned there, it is just for fun.
Config.SNOWBALL = {
	-- Y is the arena floor, just above the slate path that runs under it.
	CENTER = Vector3.new(0, 0.62, 182),
	RADIUS = 32,
	COOLDOWN = 0.4, -- seconds between throws
	SPEED = 95, -- studs per second for a player's throw
	BOT_SPEED = 58,
	GRAVITY = 60,
	BOTS = 5,
}

-- Christmas Playground attractions around the plaza. Rides cost a little
-- Cheer; the rink and the snowball arena are free.
Config.PLAYGROUND = {
	TRAIN = {
		RADIUS = 136, -- track circle round the plaza
		SPEED = 22, -- studs per second
		COST = 25,
		CARS = 4,
		CAR_SPACING = 12,
		STATION_ANGLE = 285, -- degrees round the plaza
	},
	CAROUSEL = {
		CENTER = Vector3.new(161, 0, -93),
		RADIUS = 11,
		SPIN = 0.55, -- radians per second
		COST = 10,
		SEATS = 8,
		DURATION = 30,
	},
	RINK = {
		CENTER = Vector3.new(161, 0, 93),
		RADIUS = 24,
		ICE_Y = 0.62, -- top of the ice, just above the slate path under it
	},
	-- Everyone lands here, in front of a row of gates, one for each game.
	LANDING = Vector3.new(0, 0.6, -105),
	GATE_DISTANCE = 40,
	GATES = {
		{ id = "Snowball", text = "❄️ Snowball Fight", color = Color3.fromRGB(70, 150, 220) },
		{ id = "Train", text = "🚂 North Pole Express", color = Color3.fromRGB(35, 130, 75) },
		{ id = "Workshop", text = "🎁 Santa's Workshop", color = Color3.fromRGB(200, 40, 50) },
		{ id = "Carousel", text = "🎠 Reindeer Carousel", color = Color3.fromRGB(150, 80, 200) },
		{ id = "Rink", text = "⛸ Ice Rink", color = Color3.fromRGB(60, 170, 200) },
	},
	-- Cheer a brand-new player starts with, enough for a few rides.
	STARTING_CHEER = 100,
}

Config.SACK = {
	MAX_LEVEL = 20,
	BASE_CAPACITY = 1000,
	CAPACITY_GROWTH = 2.3,
	BASE_COST = 200,
	COST_GROWTH = 2.6,
	AUTOLOAD_INTERVAL = 5, -- Auto Loader game pass
}

export type SleighUpgradeDef = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	baseCost: number,
	growth: number,
}

Config.SLEIGH_UPGRADES = {
	{
		id = "speed",
		name = "Reindeer Speed",
		description = "Fly faster over town",
		maxLevel = 10,
		baseCost = 2000,
		growth = 2.5,
	},
	{
		id = "magnet",
		name = "Present Magnet",
		description = "Wider chimney drop range",
		maxLevel = 10,
		baseCost = 3000,
		growth = 2.5,
	},
	{
		id = "time",
		name = "Night Length",
		description = "+10s flight time per level",
		maxLevel = 10,
		baseCost = 5000,
		growth = 2.6,
	},
} :: { SleighUpgradeDef }

Config.SLEIGH = {
	BASE_SPEED = 55,
	SPEED_PER_LEVEL = 7,
	BASE_RADIUS = 12,
	RADIUS_PER_LEVEL = 2,
	BASE_TIME = 60,
	TIME_PER_LEVEL = 10,
	ALTITUDE = 62, -- studs above town ground
	COOLDOWN = 20,
	REWARD_INCOME_SECONDS = 4, -- each present pays this many seconds of workshop income
	MIN_REWARD = 30,
	SNOWFLAKE_EVERY = 4, -- 1 snowflake per N presents in a run
	COMBO_WINDOW = 4, -- seconds between drops to keep a combo
	COMBO_STEP = 0.1, -- +10% per combo step
	COMBO_MAX = 2.0,
	LATENCY_SLACK = 8, -- studs of forgiveness for network delay
}

--------------------------------------------------------------------------------
-- Delivery routes: the levels of the Sleigh Delivery game. Each route lights
-- up a different set of houses and is harder than the last. Earning at least
-- one star unlocks the next route; three stars needs upgrades and practice.
--------------------------------------------------------------------------------
export type RouteDef = {
	id: number,
	name: string,
	emoji: string,
	houses: number, -- chimneys lit on this route
	stars: { number }, -- presents needed for 1, 2 and 3 stars
	time: number, -- seconds before Night Length upgrades
	reward: number, -- Cheer multiplier per present
	coal: number, -- naughty houses: dropping there costs time and combo
	golden: number, -- golden houses: triple Cheer and a snowflake
	wind: number, -- sideways gust strength in studs/second
	radius: number, -- drop range multiplier (lower = tighter aim)
	fog: boolean, -- blizzard hides far-away houses
	blurb: string,
}

local function route(
	id: number,
	name: string,
	emoji: string,
	houses: number,
	stars: { number },
	time: number,
	reward: number,
	coal: number,
	golden: number,
	wind: number,
	radius: number,
	fog: boolean,
	blurb: string
): RouteDef
	return {
		id = id,
		name = name,
		emoji = emoji,
		houses = houses,
		stars = stars,
		time = time,
		reward = reward,
		coal = coal,
		golden = golden,
		wind = wind,
		radius = radius,
		fog = fog,
		blurb = blurb,
	}
end

-- stylua: ignore
Config.ROUTES = {
	--    id  name                 emoji  houses stars          time reward coal gold wind radius fog
	route(1, "Snowy Lane",        "🏡", 18, { 4, 8, 12 },   60, 1.0, 0,  1, 0,  1.00, false, "A calm night to learn the reins."),
	route(2, "Candy Cane Court",  "🍭", 20, { 6, 10, 14 },  60, 1.4, 3,  2, 0,  1.00, false, "Watch out for naughty houses!"),
	route(3, "Gingerbread Row",   "🍪", 22, { 8, 12, 16 },  60, 1.9, 5,  2, 9,  1.00, false, "A breeze starts pushing the sleigh."),
	route(4, "Frostbite Hills",   "🧊", 24, { 10, 14, 18 }, 55, 2.5, 6,  2, 13, 0.90, false, "Less time and smaller chimneys."),
	route(5, "Blizzard Pass",     "🌨", 26, { 12, 16, 20 }, 55, 3.2, 8,  3, 15, 0.90, true,  "A blizzard hides the houses ahead."),
	route(6, "Aurora Heights",    "🌌", 28, { 14, 19, 24 }, 50, 4.0, 10, 3, 17, 0.85, false, "Strong gusts under the northern lights."),
	route(7, "Midnight Express",  "🚂", 30, { 16, 22, 27 }, 50, 5.0, 12, 3, 20, 0.80, true,  "Fast, foggy and full of coal."),
	route(8, "North Pole Finale", "🎅", 34, { 19, 25, 31 }, 45, 6.5, 14, 4, 24, 0.75, true,  "Only legends finish Santa's own route."),
} :: { RouteDef }

Config.ROUTE = {
	COAL_TIME_PENALTY = 4, -- seconds lost for dropping on a naughty house
	GOLDEN_MULTIPLIER = 3,
	STAR_SNOWFLAKES = 10, -- per new star, times the route number
	XP_PER_PRESENT = 6, -- times the route number
	XP_PER_STAR = 60, -- times the route number, first time only
}

--------------------------------------------------------------------------------
-- Helper Rank: an account level. XP comes from everything you do; each rank
-- gives a small permanent Cheer bonus and is shown above your head.
--------------------------------------------------------------------------------
Config.RANK = {
	XP_BASE = 80, -- XP for rank 1 -> 2
	XP_GROWTH = 1.22,
	MAX = 60,
	BONUS_EACH = 0.02, -- +2% Cheer per rank above 1
	SNOWFLAKES_EACH = 5,
	XP_LOAD = 4, -- loading the sleigh
	XP_BUILD = 40, -- building a machine
	XP_UPGRADE = 5,
	XP_HATCH = 12,
	XP_ELF = 15,
	XP_REBIRTH = 400,
	TITLES = {
		{ rank = 1, title = "Trainee Elf" },
		{ rank = 5, title = "Toy Tinkerer" },
		{ rank = 10, title = "Gift Wrapper" },
		{ rank = 15, title = "Sleigh Loader" },
		{ rank = 20, title = "Reindeer Wrangler" },
		{ rank = 30, title = "Chimney Champion" },
		{ rank = 40, title = "Santa's Right Hand" },
		{ rank = 50, title = "Christmas Legend" },
	},
}

-------------------------------------------------------------------------------
-- Prestige ("New Season")
-------------------------------------------------------------------------------
Config.REBIRTH = {
	BASE_COST = 25000000,
	COST_GROWTH = 3,
	BONUS_EACH = 0.5, -- +50% permanent income per rebirth
	SNOWFLAKE_REWARD = 100,
}

-------------------------------------------------------------------------------
-- Pet reindeer
-------------------------------------------------------------------------------
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Exclusive"

export type PetDef = {
	id: string,
	name: string,
	rarity: Rarity,
	bonus: number, -- additive income multiplier, e.g. 0.1 = +10%
	body: Color3,
	accent: Color3,
	nose: Color3,
	sparkle: boolean,
}

Config.RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(110, 220, 120),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
	Mythic = Color3.fromRGB(255, 80, 120),
	Exclusive = Color3.fromRGB(120, 255, 230),
} :: { [string]: Color3 }

Config.PETS = {
	Cocoa = {
		id = "Cocoa",
		name = "Cocoa",
		rarity = "Common",
		bonus = 0.1,
		body = Color3.fromRGB(140, 90, 55),
		accent = Color3.fromRGB(230, 210, 180),
		nose = Color3.fromRGB(40, 30, 30),
		sparkle = false,
	},
	Pinecone = {
		id = "Pinecone",
		name = "Pinecone",
		rarity = "Uncommon",
		bonus = 0.2,
		body = Color3.fromRGB(110, 75, 50),
		accent = Color3.fromRGB(60, 140, 80),
		nose = Color3.fromRGB(40, 30, 30),
		sparkle = false,
	},
	Frostbite = {
		id = "Frostbite",
		name = "Frostbite",
		rarity = "Rare",
		bonus = 0.4,
		body = Color3.fromRGB(225, 240, 255),
		accent = Color3.fromRGB(120, 190, 255),
		nose = Color3.fromRGB(80, 160, 255),
		sparkle = false,
	},
	Twinkle = {
		id = "Twinkle",
		name = "Twinkle",
		rarity = "Epic",
		bonus = 0.8,
		body = Color3.fromRGB(150, 90, 200),
		accent = Color3.fromRGB(255, 220, 120),
		nose = Color3.fromRGB(255, 120, 200),
		sparkle = true,
	},
	Starlight = {
		id = "Starlight",
		name = "Starlight",
		rarity = "Legendary",
		bonus = 2.0,
		body = Color3.fromRGB(255, 225, 140),
		accent = Color3.fromRGB(255, 255, 255),
		nose = Color3.fromRGB(255, 70, 70),
		sparkle = true,
	},
	Nebula = {
		id = "Nebula",
		name = "Nebula",
		rarity = "Mythic",
		bonus = 5.0,
		body = Color3.fromRGB(40, 30, 90),
		accent = Color3.fromRGB(255, 120, 230),
		nose = Color3.fromRGB(120, 255, 255),
		sparkle = true,
	},
	NorthernLights = {
		id = "NorthernLights",
		name = "Northern Lights",
		rarity = "Exclusive",
		bonus = 4.0,
		body = Color3.fromRGB(40, 90, 110),
		accent = Color3.fromRGB(120, 255, 200),
		nose = Color3.fromRGB(180, 120, 255),
		sparkle = true,
	},
} :: { [string]: PetDef }

Config.GOLDEN_MULTIPLIER = 2.5
Config.EVOLVE_COUNT = 3 -- three identical reindeer evolve into one golden one
Config.MAX_PETS = 60
Config.BASE_PET_SLOTS = 3
Config.RELEASE_REWARD_SNOWFLAKES = {
	Common = 0,
	Uncommon = 1,
	Rare = 2,
	Epic = 5,
	Legendary = 15,
	Mythic = 40,
	Exclusive = 0,
} :: { [string]: number }

export type EggDef = {
	id: string,
	name: string,
	currency: "coins" | "snowflakes",
	price: number,
	color: Color3,
	odds: { { pet: string, weight: number } },
}

Config.EGGS = {
	{
		id = "Snowdrift",
		name = "Snowdrift Egg",
		currency = "coins",
		price = 1000,
		color = Color3.fromRGB(235, 245, 255),
		odds = {
			{ pet = "Cocoa", weight = 60 },
			{ pet = "Pinecone", weight = 28 },
			{ pet = "Frostbite", weight = 10 },
			{ pet = "Twinkle", weight = 2 },
		},
	},
	{
		id = "Aurora",
		name = "Aurora Egg",
		currency = "coins",
		price = 50000,
		color = Color3.fromRGB(140, 255, 200),
		odds = {
			{ pet = "Pinecone", weight = 50 },
			{ pet = "Frostbite", weight = 32 },
			{ pet = "Twinkle", weight = 14 },
			{ pet = "Starlight", weight = 4 },
		},
	},
	{
		id = "Comet",
		name = "Comet Egg",
		currency = "coins",
		price = 2500000,
		color = Color3.fromRGB(255, 200, 90),
		odds = {
			{ pet = "Frostbite", weight = 55 },
			{ pet = "Twinkle", weight = 33 },
			{ pet = "Starlight", weight = 10.5 },
			{ pet = "Nebula", weight = 1.5 },
		},
	},
	{
		id = "Snowflake",
		name = "Snowflake Egg",
		currency = "snowflakes",
		price = 150,
		color = Color3.fromRGB(150, 200, 255),
		odds = {
			{ pet = "Twinkle", weight = 70 },
			{ pet = "Starlight", weight = 27 },
			{ pet = "Nebula", weight = 3 },
		},
	},
} :: { EggDef }

Config.LUCKY_RARITIES = { Epic = true, Legendary = true, Mythic = true } :: { [string]: boolean }
Config.LUCKY_MULTIPLIER = 2

-------------------------------------------------------------------------------
-- Cosmetics (pure style, no stats)
-------------------------------------------------------------------------------
export type CosmeticDef = {
	id: string,
	name: string,
	slot: "hat" | "sweater" | "trail",
	currency: "coins" | "snowflakes" | "free" | "event" | "robux",
	price: number,
	colorA: Color3,
	colorB: Color3,
	motif: string?, -- sweater emoji pattern
}

Config.COSMETICS = {
	-- Hats
	{
		id = "SantaHat",
		name = "Santa Hat",
		slot = "hat",
		currency = "free",
		price = 0,
		colorA = Color3.fromRGB(210, 40, 45),
		colorB = Color3.new(1, 1, 1),
	},
	{
		id = "ElfHat",
		name = "Elf Hat",
		slot = "hat",
		currency = "coins",
		price = 2500,
		colorA = Color3.fromRGB(40, 160, 70),
		colorB = Color3.fromRGB(220, 40, 45),
	},
	{
		id = "Antlers",
		name = "Reindeer Antlers",
		slot = "hat",
		currency = "coins",
		price = 15000,
		colorA = Color3.fromRGB(150, 105, 65),
		colorB = Color3.fromRGB(240, 60, 60),
	},
	{
		id = "TopHat",
		name = "Snowman Top Hat",
		slot = "hat",
		currency = "coins",
		price = 75000,
		colorA = Color3.fromRGB(30, 30, 35),
		colorB = Color3.fromRGB(200, 40, 45),
	},
	{
		id = "StarHalo",
		name = "Star Halo",
		slot = "hat",
		currency = "snowflakes",
		price = 40,
		colorA = Color3.fromRGB(255, 220, 90),
		colorB = Color3.fromRGB(255, 255, 200),
	},
	{
		id = "GingerCrown",
		name = "Gingerbread Crown",
		slot = "hat",
		currency = "snowflakes",
		price = 120,
		colorA = Color3.fromRGB(190, 120, 60),
		colorB = Color3.new(1, 1, 1),
	},
	{
		id = "HollyHat",
		name = "Holly Headband",
		slot = "hat",
		currency = "event",
		price = 0,
		colorA = Color3.fromRGB(30, 130, 60),
		colorB = Color3.fromRGB(220, 30, 40),
	},
	{
		id = "GoldenCrown",
		name = "Golden Crown",
		slot = "hat",
		currency = "robux",
		price = 0,
		colorA = Color3.fromRGB(255, 200, 40),
		colorB = Color3.fromRGB(255, 80, 120),
	},
	-- Ugly sweaters
	{
		id = "ClassicSweater",
		name = "Classic Red Sweater",
		slot = "sweater",
		currency = "coins",
		price = 1000,
		colorA = Color3.fromRGB(200, 35, 45),
		colorB = Color3.new(1, 1, 1),
		motif = "❄ 🎄 ❄",
	},
	{
		id = "EvergreenSweater",
		name = "Evergreen Sweater",
		slot = "sweater",
		currency = "coins",
		price = 8000,
		colorA = Color3.fromRGB(30, 120, 60),
		colorB = Color3.fromRGB(255, 220, 90),
		motif = "⭐ 🎁 ⭐",
	},
	{
		id = "ReindeerSweater",
		name = "Reindeer Sweater",
		slot = "sweater",
		currency = "coins",
		price = 40000,
		colorA = Color3.fromRGB(110, 70, 45),
		colorB = Color3.fromRGB(255, 80, 80),
		motif = "🦌 🦌",
	},
	{
		id = "SnowmanSweater",
		name = "Snowman Sweater",
		slot = "sweater",
		currency = "snowflakes",
		price = 60,
		colorA = Color3.fromRGB(40, 80, 160),
		colorB = Color3.new(1, 1, 1),
		motif = "⛄ ❄ ⛄",
	},
	{
		id = "GingerSweater",
		name = "Gingerbread Sweater",
		slot = "sweater",
		currency = "event",
		price = 0,
		colorA = Color3.fromRGB(170, 100, 50),
		colorB = Color3.new(1, 1, 1),
		motif = "🍪 🍬 🍪",
	},
	-- Trails
	{
		id = "CandyTrail",
		name = "Candy Cane Trail",
		slot = "trail",
		currency = "event",
		price = 0,
		colorA = Color3.fromRGB(230, 40, 50),
		colorB = Color3.new(1, 1, 1),
	},
	{
		id = "SnowTrail",
		name = "Snowflake Trail",
		slot = "trail",
		currency = "coins",
		price = 20000,
		colorA = Color3.new(1, 1, 1),
		colorB = Color3.fromRGB(140, 200, 255),
	},
	{
		id = "EvergreenTrail",
		name = "Evergreen Trail",
		slot = "trail",
		currency = "snowflakes",
		price = 90,
		colorA = Color3.fromRGB(40, 180, 80),
		colorB = Color3.fromRGB(255, 215, 80),
	},
	{
		id = "AuroraTrail",
		name = "Aurora Trail",
		slot = "trail",
		currency = "snowflakes",
		price = 300,
		colorA = Color3.fromRGB(80, 255, 190),
		colorB = Color3.fromRGB(190, 110, 255),
	},
} :: { CosmeticDef }

-------------------------------------------------------------------------------
-- Daily rewards, advent calendar, playtime gifts, present drops
-------------------------------------------------------------------------------
export type RewardDef = {
	kind: "coins" | "snowflakes" | "boost" | "eggToken" | "cosmetic" | "pet",
	amount: number, -- coins: minutes of income (with a floor); snowflakes: count; boost: minutes
	floor: number?,
	id: string?,
	label: string,
}

Config.DAILY_STREAK = {
	{ kind = "coins", amount = 2, floor = 500, label = "Bag of Cheer" },
	{ kind = "snowflakes", amount = 10, label = "10 Snowflakes" },
	{ kind = "boost", amount = 10, label = "Hot Cocoa (10 min x2)" },
	{ kind = "coins", amount = 6, floor = 2500, label = "Sack of Cheer" },
	{ kind = "snowflakes", amount = 25, label = "25 Snowflakes" },
	{ kind = "eggToken", amount = 1, label = "Free Best-Egg Hatch" },
	{ kind = "snowflakes", amount = 75, label = "75 Snowflakes!" },
} :: { RewardDef }

-- Advent doors: day -> reward. Days not listed give 10 + day snowflakes.
Config.ADVENT_SPECIAL = {
	[7] = { kind = "cosmetic", amount = 1, id = "HollyHat", label = "Holly Headband" },
	[14] = { kind = "cosmetic", amount = 1, id = "CandyTrail", label = "Candy Cane Trail" },
	[21] = { kind = "cosmetic", amount = 1, id = "GingerSweater", label = "Gingerbread Sweater" },
	[25] = { kind = "pet", amount = 1, id = "Starlight", label = "Starlight Reindeer!" },
} :: { [number]: RewardDef }

Config.PLAYTIME_GIFTS = {
	{ minutes = 3, reward = { kind = "coins", amount = 1, floor = 250, label = "Cheer" } },
	{ minutes = 8, reward = { kind = "snowflakes", amount = 5, label = "5 Snowflakes" } },
	{ minutes = 15, reward = { kind = "boost", amount = 5, label = "Hot Cocoa (5 min)" } },
	{ minutes = 25, reward = { kind = "coins", amount = 5, floor = 2000, label = "Big Cheer" } },
	{ minutes = 40, reward = { kind = "snowflakes", amount = 15, label = "15 Snowflakes" } },
	{ minutes = 60, reward = { kind = "eggToken", amount = 1, label = "Free Hatch" } },
} :: { { minutes: number, reward: RewardDef } }

Config.PRESENT_DROP = {
	INTERVAL = 360,
	LIFETIME = 45,
	INCOME_SECONDS = 60,
	MIN_COINS = 300,
	SNOWFLAKE_CHANCE = 0.5,
	SNOWFLAKES = 5,
}

Config.SLEIGH_RUSH = {
	CYCLE = 300, -- Santa's sleigh departs every 5 minutes
	RUSH_WINDOW = 45, -- loading in the last 45 seconds pays double
	MULTIPLIER = 2,
}

Config.COMMUNITY_GOAL = {
	STEP = 150, -- presents delivered by the whole server
	SNOWFLAKES = 10,
}

Config.OFFLINE = {
	MAX_SECONDS = 8 * 3600,
	RATE = 0.25,
	MIN_SECONDS = 120,
}

Config.BOOST_MULTIPLIER = 2

-------------------------------------------------------------------------------
-- Robux. Ids come from the Creator Dashboard (Monetization) of the experience.
-- An id of 0 hides the item as "coming soon" so nothing breaks before setup.
-------------------------------------------------------------------------------
export type PassDef = { key: string, id: number, name: string, description: string, robux: number }
Config.GAME_PASSES = {
	{
		key = "DoubleCheer",
		id = 2101829911,
		name = "Double Cheer",
		description = "x2 Cheer from every toy, forever.",
		robux = 99,
	},
	{
		key = "AutoLoader",
		id = 2099340685,
		name = "Elf Auto-Loader",
		description = "Your sack loads the sleigh by itself.",
		robux = 49,
	},
	{
		key = "LuckyHooves",
		id = 2099418777,
		name = "Lucky Hooves",
		description = "x2 odds for Epic, Legendary and Mythic reindeer.",
		robux = 79,
	},
	{
		key = "ExtraStall",
		id = 2099382661,
		name = "Extra Stable Stall",
		description = "Equip 1 more reindeer.",
		robux = 59,
	},
	{
		key = "VIP",
		id = 2098944677,
		name = "North Pole VIP",
		description = "Golden Crown, gold name tag and +25% Snowflakes.",
		robux = 129,
	},
} :: { PassDef }

export type ProductDef = {
	key: string,
	id: number,
	name: string,
	description: string,
	robux: number,
	grant: { kind: string, amount: number, id: string? },
}
Config.DEV_PRODUCTS = {
	{
		key = "Snowflakes100",
		id = 3736687123,
		name = "Handful of Snowflakes",
		description = "100 Snowflakes",
		robux = 19,
		grant = { kind = "snowflakes", amount = 100 },
	},
	{
		key = "Snowflakes550",
		id = 3736687283,
		name = "Snowdrift of Snowflakes",
		description = "550 Snowflakes (+10%)",
		robux = 79,
		grant = { kind = "snowflakes", amount = 550 },
	},
	{
		key = "Snowflakes1500",
		id = 3736687428,
		name = "Blizzard of Snowflakes",
		description = "1,500 Snowflakes (+25%)",
		robux = 199,
		grant = { kind = "snowflakes", amount = 1500 },
	},
	{
		key = "CocoaBoost",
		id = 3736687596,
		name = "Hot Cocoa Boost",
		description = "x2 Cheer for 30 minutes",
		robux = 15,
		grant = { kind = "boost", amount = 30 },
	},
	{
		key = "NorthernLights",
		id = 3736687720,
		name = "Northern Lights Reindeer",
		description = "Exclusive reindeer, +400% Cheer",
		robux = 149,
		grant = { kind = "pet", amount = 1, id = "NorthernLights" },
	},
} :: { ProductDef }

Config.VIP_SNOWFLAKE_BONUS = 0.25

-------------------------------------------------------------------------------
-- Sounds. All ids are from Roblox's own account or the APM Music and Pro
-- Sound Effects libraries on the Creator Store, which Roblox licenses for
-- every experience. Set an entry to "" (or {}) to switch it off.
--------------------------------------------------------------------------------
Config.SOUNDS = {
	-- Interface
	Click = "rbxassetid://15675059323",
	Pop = "rbxassetid://15675055424",
	Error = "rbxassetid://17208353912",
	Whoosh = "rbxassetid://15675024286",
	Drop = "rbxassetid://15675028888",
	-- Rewards
	Coin = "rbxassetid://9116394545",
	Purchase = "rbxassetid://10066947742",
	Star = "rbxassetid://9126073001",
	Sparkle = "rbxassetid://9125635426",
	LevelUp = "rbxassetid://1839901345",
	Win = "rbxassetid://1845399641",
	PartyHorn = "rbxassetid://9117240797",
	-- Sleigh flight
	SleighBells = "rbxassetid://1840228984",
	Wind = "rbxassetid://9113203785",
	Ticking = "rbxassetid://1839847326",
}

-- Music playlists: each track plays in turn.
Config.MUSIC = {
	-- Shuffled round the village. All from the licensed APM library on the
	-- Creator Store.
	Workshop = {
		"rbxassetid://9046738456",
		"rbxassetid://1838667764",
		"rbxassetid://9046740461",
		"rbxassetid://1839945406", -- Jingle Bells
		"rbxassetid://9046753811", -- Sleigh Ride
		"rbxassetid://1841342574", -- Santa Claus is Coming
		"rbxassetid://1839945368", -- Deck the Halls
		"rbxassetid://1841238992", -- Let it Snow
		"rbxassetid://9046741231", -- Wrapping Gifts
		"rbxassetid://9046739318", -- Snowman Song
		"rbxassetid://1835649208", -- Feliz Navidad
		"rbxassetid://1838667168", -- We Wish You A Merry Christmas
		"rbxassetid://9046757549", -- Winter Bells
	},
	Sleigh = {
		"rbxassetid://1842909673",
		"rbxassetid://9047876673",
		"rbxassetid://1839286187", -- Jingle Bells Rock
		"rbxassetid://1842988035", -- We Wish You A Merry Christmas (Rock)
	},
	Trailer = { "rbxassetid://9038460167" }, -- Christmas Frenzy
	VOLUME = 0.22,
}

-- UserIds allowed to use QA commands in live servers (Studio always allowed).
Config.ADMINS = {} :: { number }

return table.freeze(Config)
