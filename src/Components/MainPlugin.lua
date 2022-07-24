local Plugin = script:FindFirstAncestorOfClass("Plugin")
local Components = Plugin.PacketProfiler.Components
local Packages = Plugin.PacketProfiler.Packages

local Roact = require(Packages.Roact)
local Signal = require(Packages.Signal)

local PacketProfiler = require(Components.PacketProfiler)
local PacketChart = require(Components.PacketChart)

local MainPlugin = Roact.Component:extend("MainPlugin")

function MainPlugin:init()
	self.PacketProfilerEnabled, self.SetPacketProfilerEnabled = Roact.createBinding(Plugin:GetSetting("PacketProfilerEnabled") == true)
	self.OnPacketProfilerEnabled = Signal.new()

	self.IsPacketChartEnabled = Plugin:GetSetting("PacketChartEnabled") == true
	self.OnPacketChartEnabled = Signal.new()

	self.props.PacketProfiler:SetActive(self.PacketProfilerEnabled:getValue())
	self.props.PacketChart:SetActive(self.IsPacketChartEnabled)

	self.Signals = {
		ProfilerFrameSelected = Signal.new(),
	}
end

function MainPlugin:didMount()
	self.PacketProfilerClick = self.props.PacketProfiler.Click:Connect(function()
		local IsEnabled = not self.PacketProfilerEnabled:getValue()
		self.SetPacketProfilerEnabled(IsEnabled)
		self.OnPacketProfilerEnabled:Fire(IsEnabled)
		Plugin:SetSetting("PacketProfilerEnabled", IsEnabled)
	end)
	self.PacketChartClick = self.props.PacketChart.Click:Connect(function()
		local IsEnabled = not self.IsPacketChartEnabled
		self.IsPacketChartEnabled = IsEnabled
		self.OnPacketChartEnabled:Fire(IsEnabled)
		Plugin:SetSetting("PacketChartEnabled", IsEnabled)
	end)
end

function MainPlugin:render()
	return Roact.createFragment({
		PacketProfiler = Roact.createElement(PacketProfiler, {
			Enabled = self.PacketProfilerEnabled,
			OnEnabled = self.OnPacketProfilerEnabled,
			Signals = self.Signals,
		}),
		PacketChart = Roact.createElement(PacketChart, {
			Enabled = self.IsPacketChartEnabled,
			OnEnabled = self.OnPacketChartEnabled,
			Signals = self.Signals,
		}),
	})
end

function MainPlugin:willUnmount()
	self.PacketProfilerClick:Disconnect()
	self.PacketChartClick:Disconnect()
end

return MainPlugin