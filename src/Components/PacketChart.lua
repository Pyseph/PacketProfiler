local RunService = game:GetService("RunService")

local Plugin = script:FindFirstAncestorOfClass("Plugin")
local Packages = Plugin.PacketProfiler.Packages
local Components = Plugin.PacketProfiler.Components

local Roact = require(Packages.Roact)
local Signal = require(Packages.Signal)

local StudioWidget = require(Components.StudioWidget)
local StudioTheme = require(Components.StudioTheme)
local PacketCircleArcs = require(Components.PacketCircleArcs)

local GOLDEN_RATIO_CONJUGATE = 0.6180339887498948482045868343
local PIE_CHART_SIZE = 100
local DATA_LIST_OFFSET = 10

local IsEditMode = RunService:IsEdit()

local HueValue = 0
local function GetRemoteColor()
	HueValue = (HueValue + GOLDEN_RATIO_CONJUGATE) % 1

	local Color = Color3.fromHSV(HueValue, 0.5, 0.95)
	return Color
end

local function DataChartItems(props)
	local ChartItems = {}

	for _, Arc in next, props.Arcs do
		ChartItems[-Arc.Percent] = StudioTheme(function(Theme: StudioTheme)
			return Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 22),
			}, {
				Information = Roact.createElement("TextLabel", {
					Font = Enum.Font.SourceSans,
					Text = string.format("<font color=\"#%s\"><b>%s</b></font>: %.1f%%, %.2fKB", Arc.Color:ToHex(), Arc.Name, Arc.Percent, Arc.DataSize / 1000),
					RichText = true,
					TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.BrightText),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20),
					ZIndex = 3,
				}),
				BottomLine = Roact.createElement("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Separator),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 1),
				})
			})
		end)
	end

	return Roact.createFragment(ChartItems)
end

local PacketChart = Roact.Component:extend("PacketChart")

function PacketChart:init()
	self.ArcsUpdated = Signal.new()

	self:setState({
		Arcs = {},
	})
end

function PacketChart:didMount()
	self.props.Signals.ProfilerFrameSelected:Connect(function(FrameData)
		local ArcSizes = {}

		for _, Packet in next, FrameData.Packets do
			local RemoteName = Packet.RemoteName
			local PacketSize = Packet.Size

			if not ArcSizes[RemoteName] then
				ArcSizes[RemoteName] = 0
			end
			ArcSizes[RemoteName] += PacketSize
		end

		local Arcs = {}
		local TotalSize = FrameData.TotalSize
		for RemoteName, PacketSize in next, ArcSizes do
			local Percent = PacketSize / TotalSize
			local Color = GetRemoteColor()
			table.insert(Arcs, {
				Name = RemoteName,
				DataSize = PacketSize,
				Percent = Percent * 100,
				Color = Color,
			})
		end

		table.sort(Arcs, function(a, b)
			return a.Percent > b.Percent
		end)

		self:setState({
			Arcs = Arcs,
		})
	end)
end

function PacketChart:render()
	return Roact.createElement(StudioWidget, {
		WidgetId = "PacketChart",
		WidgetTitle = "Packet Chart",
		InitialDockState = Enum.InitialDockState.Float,
		Enabled = self.props.Enabled,
		OnEnabled = self.props.OnEnabled,
		DefaultSize = Vector2.new(350, 200),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		MinimumSize = Vector2.new(300, 100),
	}, {
		Background = StudioTheme(function(Theme: StudioTheme)
			return Roact.createElement("Frame", {
				BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				BorderSizePixel = 0,
				ZIndex = 0,
				Size = UDim2.fromScale(1, 1),
			})
		end),
		BackgroundCircle = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(PIE_CHART_SIZE, PIE_CHART_SIZE),
			Visible = not IsEditMode,
		}, {
			PacketCircle = Roact.createElement(PacketCircleArcs, {
				Arcs = self.state.Arcs,
			}),
		}),
		DataList = StudioTheme(function(Theme: StudioTheme)
			return Roact.createElement("ScrollingFrame", {
				BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				Size = UDim2.new(1, -PIE_CHART_SIZE - DATA_LIST_OFFSET, 1, 0),
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BorderSizePixel = 0,
				Visible = not IsEditMode,

				BottomImage = "rbxassetid://5234388158",
				MidImage = "rbxassetid://5234388158",
				TopImage = "rbxassetid://5234388158",
				ScrollBarImageColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Light),
				ScrollBarThickness = 6,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
				}),
				Items = Roact.createElement(DataChartItems, {
					Arcs = self.state.Arcs,
				})
			})
		end),
		EditModeNotifier = StudioTheme(function(Theme: StudioTheme)
			return Roact.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "Start session to begin",
				TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.WarningText),
				TextSize = 20,
				Font = Enum.Font.SourceSans,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Visible = IsEditMode,
			})
		end),
	})
end

return PacketChart