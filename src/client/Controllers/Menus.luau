--!strict
-- Owns the menu ScreenGui and every panel; opens them on request and keeps
-- the open one in sync with the latest state.

local UserInputService = game:GetService("UserInputService")

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local State = require(Lib.State)
local Bus = require(Lib.Bus)
local Panels = Lib:WaitForChild("Panels")

local Menus = {}

type PanelHandle = { panel: UI.Panel, refresh: (any) -> (), show: (string) -> () }

local panels: { [string]: PanelHandle } = {}

function Menus.init()
	local screen = UI.screen("Menus", 10)
	panels.Workshop = require(Panels.WorkshopPanel).build(screen)
	panels.Pets = require(Panels.PetsPanel).build(screen)
	panels.Gifts = require(Panels.GiftsPanel).build(screen)
	panels.Wardrobe = require(Panels.WardrobePanel).build(screen)
	panels.Store = require(Panels.StorePanel).build(screen)
end

function Menus.start()
	Bus.on("OpenMenu", function(name: string, tab: string?)
		local handle = panels[name]
		if not handle then
			return
		end
		if handle.panel.isOpen() and not tab then
			handle.panel.close()
			return
		end
		if State.data then
			handle.refresh(State.data)
		end
		if tab then
			handle.show(tab)
		end
		handle.panel.open()
	end)
	Bus.on("CloseMenus", function()
		UI.closeAll()
	end)

	State.onChanged(function(snapshot)
		for _, handle in panels do
			if handle.panel.isOpen() then
				handle.refresh(snapshot)
			end
		end
	end)

	-- Keyboard shortcuts for desktop players.
	local keys = {
		[Enum.KeyCode.B] = "Workshop",
		[Enum.KeyCode.P] = "Pets",
		[Enum.KeyCode.G] = "Gifts",
		[Enum.KeyCode.C] = "Wardrobe",
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local name = keys[input.KeyCode]
		if name then
			Bus.fire("OpenMenu", name)
		end
	end)
end

return Menus
