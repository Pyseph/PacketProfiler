local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local function StudioWidget(props)
	local info = DockWidgetPluginGuiInfo.new(
		props.InitialDockState,
		props.Enabled(),
		false,
		props.DefaultSize.X,
		props.DefaultSize.Y,
		props.MinimumSize.X,
		props.MinimumSize.Y
	)
	local widget = props.Plugin:CreateDockWidgetPluginGui(props.WidgetId, info)
	widget.Title = props.WidgetTitle
	widget.Name = props.WidgetId
	widget.ZIndexBehavior = props.ZIndexBehavior or Enum.ZIndexBehavior.Global

	Vide.cleanup(widget)
	Vide.cleanup(widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not widget.Enabled and props.Enabled() then
			props.OnEnabled(false)
		end
	end))
	Vide.effect(function()
		widget.Enabled = props.Enabled()
	end)

	return widget
end

return StudioWidget
