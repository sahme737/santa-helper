--!strict
-- Christmas Playground client entry point. Controllers only render state and
-- request actions; the server decides every outcome.

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"Audio",
	"HUD",
	"Menus",
	"Popups",
	"Tutorial",
	"WrapStation",
	"SleighFlight",
	"WorkshopFX",
	"WorldLife",
	"Snowball",
	"Rides",
	"PetFollow",
	"Snowfall",
	"Prompts",
	"Trailer",
}

local loaded: { any } = {}
for _, name in ORDER do
	local module = Controllers:WaitForChild(name)
	local ok, controller = pcall(require, module)
	if ok then
		table.insert(loaded, controller)
	else
		warn(`[Client] failed to load {name}: {controller}`)
	end
end

for _, controller in loaded do
	if typeof(controller.init) == "function" then
		local ok, err = pcall(controller.init)
		if not ok then
			warn(`[Client] init failed: {err}`)
		end
	end
end

for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end

print("[Christmas Playground] client started 🎄")
