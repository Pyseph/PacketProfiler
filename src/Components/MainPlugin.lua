local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PacketProfiler = script:FindFirstAncestor("PacketProfiler")
local Plugin: Plugin? = PacketProfiler:FindFirstAncestorOfClass("Plugin")
local Components = PacketProfiler.Components
local Packages = PacketProfiler.Packages

local Roact = require(Packages.Roact)
local Signal = require(Packages.Signal)

Roact.setGlobalConfig({
	elementTracing = true,
})

local IsStudio = RunService:IsStudio()

local MainPlugin = Roact.Component:extend("MainPlugin")

function MainPlugin:init()
	self.PacketProfilerEnabled, self.SetPacketProfilerEnabled = Roact.createBinding(if Plugin then Plugin:GetSetting("PacketProfilerEnabled") == true else false)
	self.OnPacketProfilerEnabled = Signal.new()

	self.IsPacketChartEnabled = if Plugin then Plugin:GetSetting("PacketChartEnabled") == true else false
	self.OnPacketChartEnabled = Signal.new()

	if IsStudio then
		self.props.PacketProfiler:SetActive(self.PacketProfilerEnabled:getValue())
		self.props.PacketChart:SetActive(self.IsPacketChartEnabled)
	end

	self.Signals = {
		ProfilerFrameSelected = Signal.new(),
		ProfilerPaused = Signal.new(),
	}

	function self.OnPacketProfilerClicked()
		local IsEnabled = not self.PacketProfilerEnabled:getValue()
		self.SetPacketProfilerEnabled(IsEnabled)
		self.OnPacketProfilerEnabled:Fire(IsEnabled)

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
	if IsStudio then
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
		PacketProfiler = Roact.createElement(require(Components.PacketProfiler), {
			Enabled = self.PacketProfilerEnabled,
			OnEnabled = self.OnPacketProfilerEnabled,
			Signals = self.Signals,
		}),
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