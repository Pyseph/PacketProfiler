local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local create = Vide.create
local read = Vide.read
local source = Vide.source
local spring = Vide.spring

local function AnimatedButton(props)
	local hovered = source(false)
	local pressed = source(false)
	local transparency = spring(function()
		local selected = read(props.Selected) == true
		if selected then
			return props.SelectedTransparency or 0.78
		elseif pressed() then
			return 0.74
		elseif hovered() then
			return 0.82
		end
		return 1
	end, 0.12, 1)

	return create("TextButton")({
		AutoButtonColor = false,
		AutoLocalize = false,
		BackgroundColor3 = function()
			return read(props.AccentColor)
		end,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansMedium,
		LayoutOrder = props.LayoutOrder,
		Size = function()
			return read(props.Size) or UDim2.fromOffset(80, 26)
		end,
		Text = function()
			return read(props.Text)
		end,
		TextColor3 = function()
			return read(props.TextColor)
		end,
		TextSize = props.TextSize or 13,
		TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd,

		Activated = props.OnClick,
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
			pressed(false)
		end,
		MouseButton1Down = function()
			pressed(true)
		end,
		MouseButton1Up = function()
			pressed(false)
		end,

		create("UICorner")({
			CornerRadius = UDim.new(0, 6),
		}),
	})
end

return AnimatedButton
