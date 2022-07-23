local Plugin = script:FindFirstAncestorOfClass("Plugin")
local Packages = Plugin.PacketAnalyzer.Packages

local Roact = require(Packages.Roact)

local StudioWidget = Roact.Component:extend("StudioWidget")

function StudioWidget:init()
	local WidgetInfo = DockWidgetPluginGuiInfo.new(
		self.props.InitialDockState,
		self.props.Enabled,
		false,
		self.props.DefaultSize.X,
		self.props.DefaultSize.Y,
		self.props.MinimumSize.X,
		self.props.MinimumSize.Y
	)

	local Widget = Plugin:CreateDockWidgetPluginGui(self.props.WidgetId, WidgetInfo)
	Widget.Title = self.props.WidgetTitle
	Widget.Name = self.props.WidgetId
	Widget.ZIndexBehavior = self.props.ZIndexBehavior or Enum.ZIndexBehavior.Global

	self.Widget = Widget
end

function StudioWidget:didMount()
	self.OnEnabled = self.props.OnEnabled:Connect(function(Enabled)
		self.Widget.Enabled = Enabled
	end)
	self.Widget:BindToClose(function()
		self.Widget.Enabled = false
	end)
end

function StudioWidget:render()
	return Roact.createElement(Roact.Portal, {
		target = self.Widget
	}, self.props[Roact.Children])
end

function StudioWidget:didUpdate(lastProps)
	if self.props.Enabled ~= lastProps.Enabled then
		self.Widget.Enabled = self.props.Enabled
	end
end

function StudioWidget:willUnmount()
	self.OnEnabled:Disconnect()
end

return StudioWidget