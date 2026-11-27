--!strict
-- Local-space layout of a workshop plot, shared so the client can animate toys
-- along the same belt the server built. Local -Z faces the hub (the entrance).
-- y = 0 is the top of the plot floor.

local PlotLayout = {}

PlotLayout.SIZE = 150
PlotLayout.RING_RADIUS = 300
PlotLayout.BELT_Z = 8
PlotLayout.BELT_Y = 1.6 -- top of the belt surface
PlotLayout.BELT_START_X = -60
PlotLayout.WRAP_X = 40
PlotLayout.SACK_X = 56
PlotLayout.BELT_SPEED = 9 -- studs per second (visual only)

-- Machine slots (index matches Config.MACHINES order).
-- Odd machines sit behind the belt, even ones in front.
local SLOT_X = { -50, -50, -30, -30, -10, -10, 10, 10 }
PlotLayout.MACHINE_SLOTS = {} :: { CFrame }
PlotLayout.MACHINE_OUTPUT = {} :: { Vector3 }
for i = 1, 8 do
	local behind = i % 2 == 1
	local z = if behind then 21 else -5
	-- Machines face the belt.
	PlotLayout.MACHINE_SLOTS[i] = CFrame.new(SLOT_X[i], 0, z)
		* CFrame.Angles(0, if behind then 0 else math.pi, 0)
	PlotLayout.MACHINE_OUTPUT[i] =
		Vector3.new(SLOT_X[i], PlotLayout.BELT_Y, PlotLayout.BELT_Z + (if behind then 2 else -2))
end

-- The wrapping table stands in front of the wrapping station, facing the entrance.
PlotLayout.WRAP_TABLE = CFrame.new(PlotLayout.WRAP_X, 0, PlotLayout.BELT_Z - 10)

-- The first two elves wrap at the table; the rest help at the machines.
PlotLayout.ELF_SLOTS = {} :: { CFrame }
PlotLayout.WRAP_ELVES = 2
PlotLayout.ELF_SLOTS[1] = PlotLayout.WRAP_TABLE
	* CFrame.new(-6.5, 0, 0)
	* CFrame.Angles(0, math.rad(-90), 0)
PlotLayout.ELF_SLOTS[2] = PlotLayout.WRAP_TABLE
	* CFrame.new(6.5, 0, 0)
	* CFrame.Angles(0, math.rad(90), 0)
for i = 1, 8 do
	local slot = PlotLayout.MACHINE_SLOTS[i]
	PlotLayout.ELF_SLOTS[i + 2] = slot * CFrame.new(7.5, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
end

PlotLayout.SPAWN = CFrame.new(0, 3, -60) * CFrame.Angles(0, math.pi, 0)
PlotLayout.LOAD_PAD = CFrame.new(38, 0, -24)
PlotLayout.SLEIGH = CFrame.new(57, 0, -26)
PlotLayout.PAD_MACHINE = CFrame.new(-24, 0, -42)
PlotLayout.PAD_DECOR = CFrame.new(-8, 0, -42)
PlotLayout.PAD_ELF = CFrame.new(8, 0, -42)
PlotLayout.SIGN = CFrame.new(-34, 0, -70)

PlotLayout.DECOR = {
	D1 = CFrame.new(0, 0, 0), -- fence follows the perimeter
	D2 = CFrame.new(-62, 0, -28),
	D3 = CFrame.new(0, 0, 0), -- light posts at the corners
	D4 = CFrame.new(-60, 0, 50),
	D5 = CFrame.new(50, 0, 50),
	D6 = CFrame.new(-62, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
	D7 = CFrame.new(0, 0, 52),
	D8 = CFrame.new(0, 0, -72),
} :: { [string]: CFrame }

-- World CFrame of plot `index` (1-based) around the hub. LookVector faces the hub.
function PlotLayout.plotCFrame(index: number, count: number): CFrame
	local angle = math.rad(30 + (index - 1) * (360 / count))
	local pos = Vector3.new(
		math.cos(angle) * PlotLayout.RING_RADIUS,
		0,
		math.sin(angle) * PlotLayout.RING_RADIUS
	)
	return CFrame.lookAt(pos, Vector3.new(0, 0, 0))
end

return PlotLayout
