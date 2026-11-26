--!strict
-- Reusable list rows for menu panels: icon, title, description, action button.

local UI = require(script.Parent.UI)

local Rows = {}

export type Row = {
	frame: Frame,
	icon: TextLabel,
	title: TextLabel,
	desc: TextLabel,
	button: TextButton,
}

function Rows.list(parent: Instance): ScrollingFrame
	local scroll = UI.scroll(parent)
	UI.make(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll }
	)
	UI.make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 10),
		Parent = scroll,
	})
	return scroll
end

function Rows.row(parent: Instance, order: number, icon: string, onClick: () -> ()): Row
	local frame = UI.card(parent, { Size = UDim2.new(1, 0, 0, 78), LayoutOrder = order })
	local iconLabel = UI.text({
		Text = icon,
		Size = UDim2.new(0, 60, 0, 60),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		MaxTextSize = 44,
		Parent = frame,
	})
	local title = UI.text({
		Text = "",
		Size = UDim2.new(0.62, -80, 0.45, 0),
		Position = UDim2.new(0, 80, 0.08, 0),
		TextColor3 = UI.Theme.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = frame,
	})
	local desc = UI.text({
		Text = "",
		Size = UDim2.new(0.62, -80, 0.36, 0),
		Position = UDim2.new(0, 80, 0.55, 0),
		TextColor3 = UI.Theme.Muted,
		FontFace = UI.BodyFont,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = frame,
	})
	local button = UI.button({
		Text = "",
		Size = UDim2.new(0.34, 0, 0, 52),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = frame,
		OnClick = onClick,
		MaxTextSize = 22,
	})
	return { frame = frame, icon = iconLabel, title = title, desc = desc, button = button }
end

-- Sets a row's button to show a price, colored by affordability.
function Rows.setPrice(row: Row, text: string, affordable: boolean, enabled: boolean)
	local color = if not enabled
		then UI.Theme.Disabled
		elseif affordable then UI.Theme.Green
		else Color3.fromRGB(200, 120, 110)
	UI.setButton(row.button, text, color)
	row.button.Active = enabled
end

return Rows
