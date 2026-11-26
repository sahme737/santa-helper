--!strict
-- Shared type definitions. The profile schema and the state snapshot the
-- server pushes to its owner live here so both sides agree.

export type PetEntry = {
	uid: string,
	id: string,
	golden: boolean,
}

export type Profile = {
	version: number,
	coins: number,
	snowflakes: number,
	lifetimeCoins: number,
	delivered: number,
	machines: { [string]: number }, -- machine id -> level (absent = not owned)
	decor: { [string]: boolean },
	elves: number,
	sackLevel: number,
	sack: number,
	sleigh: { [string]: number }, -- upgrade id -> level
	rebirths: number,
	pets: { PetEntry },
	nextPetUid: number,
	equipped: { string },
	cosmetics: {
		owned: { [string]: boolean },
		hat: string?,
		sweater: string?,
		trail: string?,
	},
	daily: { lastDay: number, streak: number },
	advent: { [string]: boolean }, -- "d1".."d25"
	boostUntil: number,
	eggTokens: number,
	lastOnline: number,
	incomeRate: number,
	receipts: { string },
	tutorialStep: number,
	createdAt: number,
}

-- Things the server knows that the profile does not hold.
export type Context = {
	passes: { [string]: boolean },
	now: number,
}

export type Breakdown = {
	base: number,
	decor: number,
	elves: number,
	pets: number,
	rebirth: number,
	pass: number,
	boost: number,
	total: number,
}

return nil
