local Players = game:GetService("Players")

local PacketProfiler = script.Parent.Parent
local Components = PacketProfiler.Components
local Modules = PacketProfiler.Modules

local Packages = require(Modules.Packages)
local Roact = require(Packages.Directory.Roact)
local Signal = require(Packages.Directory.Signal)

local StudioTheme = require(Components.StudioTheme)
local PacketFrames = require(Components.PacketFrames)
local TopbarButtonsGroup = require(Components.TopbarButtonsGroup)
local TopbarButton = require(Components.TopbarButton)

local TargetGui = Packages.IsPlugin and game:GetService("CoreGui") or Players.LocalPlayer.PlayerGui

local TOPBAR_HEIGHT = 10

local ProfilerComponent = Roact.Component:extend("PacketProfiler")

function ProfilerComponent:init()
	self:setState({
		MaxFrameSize = 1*1000,
	})

	self.PacketProfilerPaused, self.SetPacketProfilerPaused = Roact.createBinding(false)
	self.OnPacketProfilerPaused = Signal.new()

	self.OnPacketProfilerPaused:Connect(function(IsPaused)
		self.SetPacketProfilerPaused(IsPaused)
	end)

	function self.Pause(IsPaused)
		self.OnPacketProfilerPaused:Fire(IsPaused)
	end
end

function ProfilerComponent:didMount()
	self.props.Signals.ProfilerPaused:Connect(function(IsPaused)
		self.Pause(IsPaused)
	end)
end

function ProfilerComponent:render()
	-- When using in-game, Roblox's topbar is on the top-left corner and obstructs the buttons
	local LayoutDirection = Packages.IsPlugin and "Left" or "Right"
	local LayoutIndex = Packages.IsPlugin and -1 or 1
	return Roact.createElement(Roact.Portal, {
		target = TargetGui,
	}, {
		PacketProfiler = Roact.createElement("ScreenGui", {
			DisplayOrder = 10,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Background = StudioTheme(function(Theme)
				return Roact.createElement("Frame", {
					BackgroundColor3 = Theme:GetColor("Light"),
					BorderSizePixel = 1,
					BorderColor3 = Theme:GetColor("Border"),
					Size = UDim2.new(1, 0, 0, 50),
					Position = UDim2.fromOffset(0, TOPBAR_HEIGHT),
				}, {
					PacketFrames = Roact.createElement(PacketFrames, {
						Enabled = self.state.Enabled,
						MaxFrameSize = self.state.MaxFrameSize,
						OnPacketProfilerPaused = self.OnPacketProfilerPaused,
						OnPacketProfilerEnabled = self.props.OnEnabled,
						Signals = self.props.Signals,
					})
				})
			end),
			Topbar = StudioTheme(function(Theme)
				return Roact.createElement("Frame", {
					BackgroundColor3 = Theme:GetColor("Item"),
					BorderSizePixel = 0,
					ZIndex = 2,
					Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT),
				}, {
					UIListLayout = Roact.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = LayoutDirection == "Left" and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 5),
					}),
					["Title"] = Roact.createElement(TopbarButton, {
						Text = "PacketProfiler",
						Theme = Theme,
						LayoutOrder = LayoutIndex
					}),
					["MaxKBScale"] = Roact.createElement(TopbarButtonsGroup, {
						Theme = Theme,
						Text = "Max KB scale",
						Options = {
							{
								Name = "10 B",
								Callback = function()
									self:setState({
										MaxFrameSize = 10,
									})
								end,
							},
							{
								Name = "100 B",
								Callback = function()
									self:setState({
										MaxFrameSize = 100,
									})
								end,
							},
							{
								Name = "1 KB",
								Callback = function()
									self:setState({
										MaxFrameSize = 1*1000,
									})
								end,
							},
							{
								Name = "10 KB",
								Callback = function()
									self:setState({
										MaxFrameSize = 10*1000,
									})
								end,
							},
							{
								Name = "50 KB",
								Callback = function()
									self:setState({
										MaxFrameSize = 50*1000,
									})
								end,
							},
							{
								Name = "100 KB",
								Callback = function()
									self:setState({
										MaxFrameSize = 100*1000,
									})
								end
							},
						},
						LayoutOrder = LayoutIndex * 2,
					}),
					["PausedLabel"] = Roact.createElement(TopbarButton, {
						Text = self.PacketProfilerPaused:map(function(IsPaused)
							return IsPaused and "[Paused]" or "[Running]"
						end),
						Theme = Theme,
						OnClick = function()
							self.props.Signals.ProfilerPaused:Fire(not self.PacketProfilerPaused:getValue())
						end,
						LayoutIndex = LayoutIndex * 3,
					})
				})
			end),
		})
	})
end

return ProfilerComponent