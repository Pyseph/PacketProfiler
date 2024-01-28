local UserInputService = game:GetService("UserInputService")

local PacketProfiler = script.Parent.Parent
local Plugin: Plugin? = PacketProfiler:FindFirstAncestorOfClass("Plugin")
local Components = PacketProfiler.Components
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)
local Signal = require(Packages.Directory.Signal)

Roact.setGlobalConfig({
	elementTracing = true,
})

local MainPlugin = Roact.Component:extend("MainPlugin")

function MainPlugin:init()
	self.OnPacketProfilerEnabled = Signal.new()

	self.IsPacketChartEnabled = if Plugin then Plugin:GetSetting("PacketChartEnabled") == true else false
	self.OnPacketChartEnabled = Signal.new()

	self:setState({
		PacketProfilerEnabled = if Plugin then Plugin:GetSetting("PacketProfilerEnabled") == true else false,
	})
	if Packages.IsPlugin then
		self.props.PacketProfiler:SetActive(self.state.PacketProfilerEnabled)
		self.props.PacketChart:SetActive(self.IsPacketChartEnabled)
	end

	self.Signals = {
		ProfilerFrameSelected = Signal.new(),
		ProfilerPaused = Signal.new(),
	}

	function self.OnPacketProfilerClicked()
		local IsEnabled = not self.state.PacketProfilerEnabled
		self.OnPacketProfilerEnabled:Fire(IsEnabled)
		self:setState({
			PacketProfilerEnabled = IsEnabled
		})

		if Plugin then
			Plugin:SetSetting("PacketProfilerEnabled", IsEnabled)
		end
	end
	function self.OnPacketChartClicked(Override)
		local IsEnabled = if Override then Override else not self.IsPacketChartEnabled
		self.IsPacketChartEnabled = IsEnabled
		self.OnPacketChartEnabled:Fire(IsEnabled)

		if Plugin then
			Plugin:SetSetting("PacketChartEnabled", IsEnabled)
		end
	end
end

function MainPlugin:didMount()
	if Packages.IsPlugin then
		self.PacketProfilerClick = self.props.PacketProfiler.Click:Connect(self.OnPacketProfilerClicked)
		self.PacketChartClick = self.props.PacketChart.Click:Connect(self.OnPacketChartClicked)
	else
		UserInputService.InputBegan:Connect(function(InputObject)
			if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				return
			end

			if InputObject.KeyCode == Enum.KeyCode.F5 then
				self.OnPacketProfilerClicked()
			elseif InputObject.KeyCode == Enum.KeyCode.P then
				self.ProfilerPaused = not self.ProfilerPaused
				self.Signals.ProfilerPaused:Fire(self.ProfilerPaused)
			end
		end)

		self.Signals.ProfilerFrameSelected:Connect(function()
			self.OnPacketChartClicked(true)
		end)
	end
end

function MainPlugin:render()
	return Roact.createFragment({
		PacketProfiler = self.state.PacketProfilerEnabled and Roact.createElement(require(Components.PacketProfiler), {
			Enabled = true,
			OnEnabled = self.OnPacketProfilerEnabled,
			Signals = self.Signals,
		}) or nil,
		PacketChart = Roact.createElement(require(Components.PacketChart), {
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