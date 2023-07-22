local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local PacketProfiler = script.Parent.Parent
local Components = PacketProfiler.Components
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)
local StudioTheme = require(Components.StudioTheme)
local PacketFrames = require(Components.PacketFrames)
local Signal = require(Packages.Directory.Signal)

local TargetGui = Packages.IsPlugin and game:GetService("CoreGui") or Players.LocalPlayer.PlayerGui

local TOPBAR_HEIGHT = 10
local IsEditMode = not RunService:IsRunning()

local function TopbarButton(props)
	return Roact.createElement("TextButton", {
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
		[Roact.Event.Activated] = props.OnClick,
	})
end

local function TopbarOptionsButton(props)
	return Roact.createElement("TextButton", {
		Text = props.ButtonName,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.Code,
		TextColor3 = props.Theme.Name == "Light" and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
		TextSize = TOPBAR_HEIGHT + 2,
		BackgroundColor3 = props.Theme:GetColor("ScrollBarBackground"),
		Size = props.Size,
		BorderSizePixel = 0,
		[Roact.Event.Activated] = props.OnClick,
	})
end

local TopbarButtonsGroup = Roact.Component:extend("TopbarButtonsGroup")

function TopbarButtonsGroup:init()
	self.MouseHovering, self.SetMouseHovering = Roact.createBinding(0)
end

function TopbarButtonsGroup:render()
	local props = self.props
	local Buttons = {}

	local LongestButtonWidth = 0
	for _, Data in next, props.Options do
		local ButtonTextSize = TextService:GetTextSize(Data.Name, TOPBAR_HEIGHT + 1, Enum.Font.Code, Vector2.new(10000, TOPBAR_HEIGHT + 1))
		LongestButtonWidth = math.max(LongestButtonWidth, ButtonTextSize.X)
	end

	for _, Data in next, props.Options do
		table.insert(Buttons, TopbarOptionsButton({
			ButtonName = Data.Name,
			OnClick = Data.Callback,
			Theme = props.Theme,
			Size = UDim2.fromOffset(LongestButtonWidth, TOPBAR_HEIGHT + 1),
		}))
	end

	local ButtonGroupTextSize = TextService:GetTextSize(props.Text, TOPBAR_HEIGHT + 2, Enum.Font.Code, Vector2.new(10000, TOPBAR_HEIGHT + 1))
	return Roact.createElement("TextLabel", {
		Text = props.Text,
		TextColor3 = props.Theme.Name == "Light" and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
		BackgroundColor3 = self.MouseHovering:map(function(VisibleIndex)
			return VisibleIndex > 0 and props.Theme:GetColor("Light") or props.Theme:GetColor("ScrollBarBackground")
		end),
		TextSize = TOPBAR_HEIGHT + 2,
		Font = Enum.Font.Code,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(ButtonGroupTextSize.X, TOPBAR_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = not IsEditMode,
		[Roact.Event.MouseEnter] = function()
			self.SetMouseHovering(1)
		end,
		[Roact.Event.MouseLeave] = function()
			task.defer(function()
				if self.MouseHovering:getValue() == 1 then
					self.SetMouseHovering(0)
				end
			end)
		end,
	}, {
		OptionsHolder = Roact.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Visible = self.MouseHovering:map(function(VisibleIndex)
				return VisibleIndex > 0
			end),
			Position = UDim2.fromOffset(0, TOPBAR_HEIGHT),
			[Roact.Event.MouseEnter] = function()
				self.SetMouseHovering(2)
			end,
			[Roact.Event.MouseLeave] = function()
				task.defer(function()
					if self.MouseHovering:getValue() == 2 then
						self.SetMouseHovering(0)
					end
				end)
			end,
		}, {
			OptionsListLayout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			Buttons = Roact.createFragment(Buttons),
		})
	})
end

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
	return Roact.createElement(Roact.Portal, {
		target = TargetGui,
	}, {
		PacketProfiler = Roact.createElement("ScreenGui", {
			Enabled = self.props.Enabled,
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
						Enabled = self.props.Enabled,
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
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 5),
					}),
					["1Title"] = Roact.createElement(TopbarButton, {
						Text = "PacketProfiler",
						Theme = Theme,
					}),
					["2MaxKBScale"] = Roact.createElement(TopbarButtonsGroup, {
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
					}),
					["3PausedLabel"] = Roact.createElement(TopbarButton, {
						Text = self.PacketProfilerPaused:map(function(IsPaused)
							return IsPaused and "[Paused]" or "[Running]"
						end),
						Theme = Theme,
						OnClick = function()
							self.props.Signals.ProfilerPaused:Fire(not self.PacketProfilerPaused:getValue())
						end,
					})
				})
			end),
		})
	})
end

return ProfilerComponent