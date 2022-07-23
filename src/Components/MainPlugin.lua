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
	self.IsPacketChartEnabled, self.OnPacketChartEnabled = Plugin:GetSetting("PacketChartEnabled") == true, Signal.new()

	self.props.PacketProfiler:SetActive(self.PacketProfilerEnabled:getValue())
	self.props.PacketChart:SetActive(self.IsPacketChartEnabled)

	self.Signals = {
		ProfilerFrameSelected = Signal.new(),
	}
end

function MainPlugin:didMount()
	self.PacketProfilerClick = self.props.PacketProfiler.Click:Connect(function()
		self.SetPacketProfilerEnabled(not self.PacketProfilerEnabled:getValue())
		Plugin:SetSetting("PacketProfilerEnabled", self.PacketProfilerEnabled:getValue())
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