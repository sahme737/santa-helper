--!strict
-- Pure economy formulas shared by server (authoritative) and client (display).
-- No Roblox services here so the module can be unit-tested outside Roblox.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type Profile = Types.Profile
type Context = Types.Context

local Economy = {}

local MACHINE_BY_ID: { [string]: Config.MachineDef } = {}
local MACHINE_INDEX: { [string]: number } = {}
for i, m in Config.MACHINES do
	MACHINE_BY_ID[m.id] = m
	MACHINE_INDEX[m.id] = i
end
local DECOR_BY_ID: { [string]: Config.DecorDef } = {}
for _, d in Config.DECOR do
	DECOR_BY_ID[d.id] = d
end
local SLEIGH_BY_ID: { [string]: Config.SleighUpgradeDef } = {}
for _, s in Config.SLEIGH_UPGRADES do
	SLEIGH_BY_ID[s.id] = s
end

Economy.MACHINE_BY_ID = MACHINE_BY_ID
Economy.MACHINE_INDEX = MACHINE_INDEX
Economy.DECOR_BY_ID = DECOR_BY_ID
Economy.SLEIGH_BY_ID = SLEIGH_BY_ID

local function round(n: number): number
	return math.floor(n + 0.5)
end

-- Toy value for one machine at a level (before multipliers).
function Economy.toyValue(machine: Config.MachineDef, level: number): number
	return machine.value * (1 + Config.MACHINE_LEVEL_VALUE_BONUS * (level - 1))
end

function Economy.machineUpgradeCost(machine: Config.MachineDef, level: number): number
	local basis = math.max(60, machine.cost * 0.4)
	return round(basis * Config.MACHINE_UPGRADE_GROWTH ^ (level - 1))
end

function Economy.elfCost(owned: number): number
	return round(Config.ELVES.BASE_COST * Config.ELVES.GROWTH ^ owned)
end

function Economy.sackCapacity(level: number): number
	return round(Config.SACK.BASE_CAPACITY * Config.SACK.CAPACITY_GROWTH ^ level)
end

function Economy.sackCost(level: number): number
	return round(Config.SACK.BASE_COST * Config.SACK.COST_GROWTH ^ level)
end

function Economy.sleighUpgradeCost(def: Config.SleighUpgradeDef, level: number): number
	return round(def.baseCost * def.growth ^ level)
end

function Economy.rebirthCost(rebirths: number): number
	return round(Config.REBIRTH.BASE_COST * Config.REBIRTH.COST_GROWTH ^ rebirths)
end

function Economy.canRebirth(profile: Profile): boolean
	for _, m in Config.MACHINES do
		if not profile.machines[m.id] then
			return false
		end
	end
	return profile.coins >= Economy.rebirthCost(profile.rebirths)
end

function Economy.petBonus(petId: string, golden: boolean): number
	local def = Config.PETS[petId]
	if not def then
		return 0
	end
	return def.bonus * (if golden then Config.GOLDEN_MULTIPLIER else 1)
end

function Economy.petSlots(profile: Profile, passes: { [string]: boolean }): number
	local slots = Config.BASE_PET_SLOTS
	if profile.rebirths >= 1 then
		slots += 1
	end
	if profile.rebirths >= 3 then
		slots += 1
	end
	if passes.ExtraStall then
		slots += 1
	end
	return slots
end

function Economy.findPet(profile: Profile, uid: string): (Types.PetEntry?, number?)
	for i, pet in profile.pets do
		if pet.uid == uid then
			return pet, i
		end
	end
	return nil, nil
end

-- Full income multiplier breakdown; `total` is coins per second.
function Economy.breakdown(profile: Profile, ctx: Context): Types.Breakdown
	local base = 0
	for id, level in profile.machines do
		local m = MACHINE_BY_ID[id]
		if m then
			base += Economy.toyValue(m, level) / m.interval
		end
	end

	local decor = 0
	for id in profile.decor do
		local d = DECOR_BY_ID[id]
		if d then
			decor += d.bonus
		end
	end

	local pets = 0
	for _, uid in profile.equipped do
		local pet = Economy.findPet(profile, uid)
		if pet then
			pets += Economy.petBonus(pet.id, pet.golden)
		end
	end

	local elves = profile.elves * Config.ELVES.BONUS_EACH
	local rebirth = profile.rebirths * Config.REBIRTH.BONUS_EACH
	local pass = if ctx.passes.DoubleCheer then 2 else 1
	local boost = if profile.boostUntil > ctx.now then Config.BOOST_MULTIPLIER else 1

	local total = base * (1 + decor) * (1 + elves) * (1 + pets) * (1 + rebirth) * pass * boost
	return {
		base = base,
		decor = decor,
		elves = elves,
		pets = pets,
		rebirth = rebirth,
		pass = pass,
		boost = boost,
		total = total,
	}
end

function Economy.incomePerSecond(profile: Profile, ctx: Context): number
	return Economy.breakdown(profile, ctx).total
end

-- Coins reward measured in "minutes of income", never below a floor.
function Economy.scaledCoins(
	profile: Profile,
	ctx: Context,
	minutes: number,
	floor: number?
): number
	local income = Economy.incomePerSecond(profile, ctx)
	return math.max(floor or 0, round(income * 60 * minutes))
end

function Economy.sleighStats(
	profile: Profile
): { speed: number, radius: number, duration: number, reindeer: number }
	local s = profile.sleigh
	local speedLevel = s.speed or 0
	return {
		speed = Config.SLEIGH.BASE_SPEED + Config.SLEIGH.SPEED_PER_LEVEL * speedLevel,
		radius = Config.SLEIGH.BASE_RADIUS + Config.SLEIGH.RADIUS_PER_LEVEL * (s.magnet or 0),
		duration = Config.SLEIGH.BASE_TIME + Config.SLEIGH.TIME_PER_LEVEL * (s.time or 0),
		reindeer = 2 + math.floor(speedLevel / 3) * 2,
	}
end

function Economy.presentReward(profile: Profile, ctx: Context, combo: number): number
	local income = Economy.incomePerSecond(profile, ctx)
	local base = math.max(Config.SLEIGH.MIN_REWARD, income * Config.SLEIGH.REWARD_INCOME_SECONDS)
	local mult =
		math.min(Config.SLEIGH.COMBO_MAX, 1 + Config.SLEIGH.COMBO_STEP * math.max(0, combo - 1))
	return round(base * mult)
end

-- Weighted roll. `rng01` is a number in [0, 1).
function Economy.rollEgg(egg: Config.EggDef, lucky: boolean, rng01: number): string
	local total = 0
	local weights: { number } = {}
	for i, entry in egg.odds do
		local def = Config.PETS[entry.pet]
		local w = entry.weight
		if lucky and def and Config.LUCKY_RARITIES[def.rarity] then
			w *= Config.LUCKY_MULTIPLIER
		end
		weights[i] = w
		total += w
	end
	local pick = rng01 * total
	for i, entry in egg.odds do
		pick -= weights[i]
		if pick < 0 then
			return entry.pet
		end
	end
	return egg.odds[#egg.odds].pet
end

function Economy.oddsPercent(egg: Config.EggDef, lucky: boolean): { [string]: number }
	local total = 0
	local weights: { [string]: number } = {}
	for _, entry in egg.odds do
		local def = Config.PETS[entry.pet]
		local w = entry.weight
		if lucky and def and Config.LUCKY_RARITIES[def.rarity] then
			w *= Config.LUCKY_MULTIPLIER
		end
		weights[entry.pet] = w
		total += w
	end
	local out: { [string]: number } = {}
	for pet, w in weights do
		out[pet] = w / total * 100
	end
	return out
end

-- Best egg priced in coins that the player can currently afford (for free hatch tokens).
function Economy.bestCoinEgg(profile: Profile): Config.EggDef
	local best = Config.EGGS[1]
	for _, egg in Config.EGGS do
		if
			egg.currency == "coins"
			and egg.price <= math.max(profile.lifetimeCoins * 0.05, 1000)
		then
			if egg.price > best.price then
				best = egg
			end
		end
	end
	return best
end

function Economy.offlineEarnings(profile: Profile, now: number): (number, number)
	if profile.lastOnline <= 0 then
		return 0, 0
	end
	local elapsed = math.clamp(now - profile.lastOnline, 0, Config.OFFLINE.MAX_SECONDS)
	if elapsed < Config.OFFLINE.MIN_SECONDS then
		return 0, elapsed
	end
	return round(profile.incomeRate * elapsed * Config.OFFLINE.RATE), elapsed
end

return Economy
