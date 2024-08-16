local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PacketProfiler = script.Parent.Parent
local Components = PacketProfiler.Components
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)
local Signal = require(Packages.Directory.Signal)
local PacketSizeCounter = require(Packages.Directory.PacketSizeCounter)

local StudioTheme = require(Components.StudioTheme)
local PacketCircleArcs = require(Components.PacketCircleArcs)
local PacketChartItems = require(Components.PacketChartItems)
local ChartResize = require(Components.ChartResize)

local TableToSyntaxString = require(Modules.TableToSyntaxString)

local GOLDEN_RATIO_CONJUGATE = 0.6180339887498948482045868343
local PIE_CHART_SIZE = 100
local DATA_LIST_OFFSET = 20
local SCROLLBAR_THICKNESS = 10
local REMOTE_NAME_MODULE_NAME = "RemoteName.profiler"

local IsEditMode = not RunService:IsRunning()

local HueValue = 0
local function GetRemoteColor()
	HueValue = (HueValue + GOLDEN_RATIO_CONJUGATE) % 1

	local Color = Color3.fromHSV(HueValue, 0.5, 0.95)
	return Color
end

local RemoteNameModule = ReplicatedStorage:FindFirstChild(REMOTE_NAME_MODULE_NAME, true)

local RemoteNameLabeler = nil
if RemoteNameModule == nil then
	local Connection
	Connection = ReplicatedStorage.DescendantAdded:Connect(function(Descendant)
		if Descendant.Name == REMOTE_NAME_MODULE_NAME then
			assert(typeof(require(Descendant)) == "function", "Return of RemoteName.profiler must be a function")
			RemoteNameLabeler = require(Descendant)
			Connection:Disconnect()
		end
	end)
else
	assert(typeof(require(RemoteNameModule)) == "function", "Return of RemoteName.profiler must be a function")
	RemoteNameLabeler = require(RemoteNameModule)
end

local function GetRemoteData(RemoteObject: RemoteEvent, ...: any): {{Name: string, Arguments: {any}}} | string
	local RemoteData = RemoteNameLabeler and RemoteNameLabeler(RemoteObject, ...)
	if not RemoteData then
		local RemoteName = RemoteObject.Name
		return `{RemoteObject.Parent}.{RemoteName}`
	end

	return RemoteData
end

local PacketChart = Roact.Component:extend("PacketChart")

function PacketChart:init()
	self.ArcsUpdated = Signal.new()
	self.ChartEnabled, self.SetChartEnabled = Roact.createBinding(false)
	self.ScrollBarChanged, self.SetScrollBarChanged = Roact.createBinding({
		Size = 0,
		Visible = false,
	})

	self.OpenRemoteData = Signal.new()

	self:setState({
		Arcs = {},
	})
end

function PacketChart:didMount()
	self.props.Signals.ProfilerFrameSelected:Connect(function(FrameData)
		local ArcData = {}

		for _, Packet in FrameData.Packets do
			local RemoteData = GetRemoteData(Packet.Remote, unpack(Packet.RawData))
			if typeof(RemoteData) == "string" then
				local RemoteName = RemoteData
				local PacketSize = Packet.Size

				if not ArcData[RemoteName] then
					ArcData[RemoteName] = {
						Size = 0,
						Data = {},
					}
				end
				ArcData[RemoteName].Size += PacketSize

				local PlacementIndex = #ArcData[RemoteName].Data + 1
				ArcData[RemoteName].Data[PlacementIndex] = {
					Name = `Remote call {PlacementIndex}:`,
					Packet = `{Packet.Data and TableToSyntaxString(Packet.Data) or "[None]"}`
				}
			else
				local NumRemotes = 0
				for _ in RemoteData do
					NumRemotes += 1
				end

				for _, RemoteCall in RemoteData do
					local RemoteName = RemoteCall.Name
					local PacketSize = PacketSizeCounter.GetPacketSize({
						RunContext = Packet.RunContext,
						RemoteType = "RemoteEvent",
						PacketData = RemoteCall.Arguments,
					}) - PacketSizeCounter.BaseRemoteOverhead

					if Packet.RunContext == "Client" then
						PacketSize -= PacketSizeCounter.ClientToServerOverhead
					end

					if not ArcData[RemoteName] then
						ArcData[RemoteName] = {
							Size = 0,
							Data = {},
						}
					end
					ArcData[RemoteName].Size += Packet.RawData / NumRemotes

					local PlacementIndex = #ArcData[RemoteName].Data + 1
					ArcData[RemoteName].Data[PlacementIndex] = {
						Name = RemoteCall.Name,
						Packet = TableToSyntaxString(RemoteCall.Arguments, true)
					}
				end
			end
		end

		local Arcs = {}
		local TotalSize = FrameData.TotalSize
		for RemoteName, RemoteData in ArcData do
			local Percent = RemoteData.Size / TotalSize
			local Color = GetRemoteColor()
			table.insert(Arcs, {
				Name = RemoteName,
				DataSize = RemoteData.Size,
				Percent = Percent * 100,
				Color = Color,
				RemoteData = RemoteData.Data,
			})
		end

		table.sort(Arcs, function(a, b)
			return a.Percent > b.Percent
		end)

		self:setState({
			Arcs = Arcs,
		})
	end)
	self.props.Signals.ProfilerPaused:Connect(function(IsPaused)
		self.SetChartEnabled(IsPaused)
	end)
	self.props.OnEnabled:Connect(function(IsEnabled)
		self.SetChartEnabled(IsEnabled)
	end)
end

function PacketChart:render()
	return Roact.createElement(Packages.IsPlugin and require(Components.StudioWidget) or "ScreenGui", ({
		Plugin = {
			WidgetId = "PacketChart",
			WidgetTitle = "Packet Chart",
			InitialDockState = Enum.InitialDockState.Float,
			Enabled = self.props.Enabled,
			OnEnabled = self.props.OnEnabled,
			DefaultSize = Vector2.new(350, 200),
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			MinimumSize = Vector2.new(300, 100),
		},
		Client = {
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			Enabled = self.ChartEnabled,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}
	})[Packages.IsPlugin and "Plugin" or "Client"], {
		Holder = StudioTheme(function(Theme)
			return ChartResize(function(ResizeData)
				return Roact.createElement("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Packages.IsPlugin and Vector2.new() or Vector2.new(1, 0),
					Position = Packages.IsPlugin and UDim2.new() or UDim2.new(1, 0, 0, 61),
					Size = Packages.IsPlugin and UDim2.fromScale(1, 1) or ResizeData.UISize,
					[Roact.Ref] = not Packages.IsPlugin and ResizeData.SetSizeTarget or nil,
				}, {
					Background = Roact.createElement("Frame", {
						BackgroundColor3 = Theme:GetColor("MainBackground"),
						BorderSizePixel = 0,
						ZIndex = 0,
						Size = UDim2.fromScale(1, 1),
					}, {
						Notches = Roact.createElement("ImageLabel", {
							AnchorPoint = Vector2.new(0, 1),
							BackgroundTransparency = 1,
							Image = "rbxassetid://18701486909",
							ImageColor3 = Theme:GetColor("BrightText"),
							ImageTransparency = 0.5,
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.fromOffset(16, 16),
						})
					}),
					UIStroke = Roact.createElement("UIStroke", {
						Color = Theme:GetColor("DropShadow"),
						Thickness = 1,
					}),
					BackgroundCircle = Roact.createElement("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(PIE_CHART_SIZE, PIE_CHART_SIZE),
						Visible = not IsEditMode,
						Position = UDim2.fromOffset(8, 8),
					}, {
						-- Creating a separate background UI to avoid updating the pie chart when studio theme updates
						BackgroundUI = Roact.createElement("Frame", {
							BackgroundColor3 = Theme:GetColor("ScrollBarBackground"),
							Size = UDim2.fromScale(1, 1),
							Visible = #self.state.Arcs > 0,
						}, {
							UIStroke = Roact.createElement("UIStroke", {
								Color = Theme:GetColor("DropShadow"),
								LineJoinMode = Enum.LineJoinMode.Round,
								Transparency = 0.5,
							}),
							UICorner = Roact.createElement("UICorner", {
								CornerRadius = UDim.new(0, 4),
							}),
						}),
						PacketCircle = Roact.createElement(PacketCircleArcs, {
							Arcs = self.state.Arcs,
							PluginMouse = self.props.PluginMouse,
						}),
					}),
					DataList = Roact.createElement("ScrollingFrame", {
						BackgroundColor3 = Theme:GetColor("MainBackground"),
						Size = UDim2.new(1, -PIE_CHART_SIZE - DATA_LIST_OFFSET - 1, 1, -1),
						Position = UDim2.new(1, -1, 0, 0),
						AnchorPoint = Vector2.new(1, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						BorderSizePixel = 0,
						BackgroundTransparency = 1,
						Visible = not IsEditMode,
						ZIndex = 2,

						BottomImage = "rbxassetid://5234388158",
						MidImage = "rbxassetid://5234388158",
						TopImage = "rbxassetid://5234388158",
						ScrollBarImageColor3 = Theme:GetColor("Light"),
						ScrollBarThickness = SCROLLBAR_THICKNESS,
						[Roact.Change.AbsoluteCanvasSize] = function(Rbx)
							self.SetScrollBarChanged({
								Size = Rbx.AbsoluteSize.Y,
								Visible = Rbx.AbsoluteSize.Y < Rbx.AbsoluteCanvasSize.Y
							})
						end,
						[Roact.Change.AbsoluteSize] = function(Rbx)
							self.SetScrollBarChanged({
								Size = Rbx.AbsoluteSize.Y,
								Visible = Rbx.AbsoluteSize.Y < Rbx.AbsoluteCanvasSize.Y
							})
						end,
					}, {
						UIListLayout = Roact.createElement("UIListLayout", {
							SortOrder = Enum.SortOrder.LayoutOrder,
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
							[Roact.Change.AbsoluteContentSize] = function(Rbx)
								Rbx.Parent.CanvasSize = UDim2.fromOffset(0, Rbx.AbsoluteContentSize.Y)
							end
						}),
						Items = Roact.createElement(PacketChartItems, {
							Arcs = self.state.Arcs,
							ScrollBarChanged = self.ScrollBarChanged,
						}),
						UIPadding = Roact.createElement("UIPadding", {
							PaddingTop = UDim.new(0, 8),
							PaddingBottom = UDim.new(0, 8),
						}),
					}),
					EditModeNotifier = Roact.createElement("TextLabel", {
						AutoLocalize = false,
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = "Start session to begin",
						TextColor3 = Theme:GetColor("WarningText"),
						TextSize = 20,
						Font = Enum.Font.SourceSans,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						Visible = IsEditMode,
					}),
					ScrollBarOutline = Roact.createElement("Frame", {
						BackgroundColor3 = Theme:GetColor("ScrollBarBackground"),
						BorderSizePixel = 0,
						Size = self.ScrollBarChanged:map(function(Data)
							return UDim2.fromOffset(SCROLLBAR_THICKNESS + 2, Data.Size)
						end),
						Position = UDim2.new(1, 0, 0, 0),
						AnchorPoint = Vector2.new(1, 0),
						Visible = self.ScrollBarChanged:map(function(ScrollBarChanged)
							return ScrollBarChanged.Visible
						end),
					}),
				})
			end)
		end)
	})
end

return PacketChart