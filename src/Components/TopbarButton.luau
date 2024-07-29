local PacketProfiler = script.Parent.Parent
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)

local TOPBAR_HEIGHT = 10

local function TopbarButton(props)
	return Roact.createElement("TextButton", {
		AutoLocalize = false,
		TextColor3 = props.Theme.Name == "Light" and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(0, TOPBAR_HEIGHT),
		BackgroundColor3 = props.Theme:GetColor("Item"),
		TextSize = TOPBAR_HEIGHT + 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Text = props.Text,
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = props.LayoutOrder,
		[Roact.Event.Activated] = props.OnClick,
	})
end

return TopbarButton