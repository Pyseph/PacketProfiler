local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PacketProfiler = script.Parent.Parent
local Components = PacketProfiler.Components
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)
local Signal = require(Packages.Directory.Signal)

local StudioTheme = require(Components.StudioTheme)
local PacketCircleArcs = require(Components.PacketCircleArcs)

local TableToSyntaxString = require(Modules.TableToSyntaxString)

local GOLDEN_RATIO_CONJUGATE = 0.6180339887498948482045868343
local PIE_CHART_SIZE = 100
local DATA_LIST_OFFSET = 20
local REMOTE_NAME_MODULE_NAME = "RemoteName.profiler"
local RICHTEXT_CHARS_LIMIT = 16383

local IsEditMode = not RunService:IsRunning()

local HueValue = 0
local function GetRemoteColor()
	HueValue = (HueValue + GOLDEN_RATIO_CONJUGATE) % 1

	local Color = Color3.fromHSV(HueValue, 0.5, 0.95)
	return Color
end
local function GetSizeUnit(Value: number): (number, string)
	if Value < 1000 then
		return Value, "B"
	elseif Value < 1000 * 1000 then
		return Value / 1000, "KB"
	else
		return Value / (1000 * 1000), "MB"
	end
end

local RemoteNameModule = ReplicatedStorage:FindFirstChild(REMOTE_NAME_MODULE_NAME)
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
	RemoteNameLabeler = require(RemoteNameLabeler)
end

local function GetRemoteName(RemoteObject: RemoteEvent, FirstArgument: any?)
	if RemoteNameLabeler ~= nil then
		return RemoteNameLabeler(RemoteObject, FirstArgument)
	else
		return RemoteObject.Name
	end
end

local DataChartItem = Roact.Component:extend("DataChartItem")

function DataChartItem:init()
	self.RemoteData, self.ShowRemoteData = Roact.createBinding(false)
end
function DataChartItem:render()
	local Arc = self.props.Arc
	return StudioTheme(function(Theme: StudioTheme)
		return Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			["1Information"] = Roact.createElement("TextButton", {
				Font = Enum.Font.SourceSans,
				Text = string.format("<font color=\"#%s\"><b>%s</b></font>: %.1f%%, %d%s", Arc.Color:ToHex(), Arc.Name, Arc.Percent, GetSizeUnit(Arc.DataSize)),
				RichText = true,
				TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.BrightText),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 20),
				ZIndex = 3,
				[Roact.Event.Activated] = function()
					self.ShowRemoteData(not self.RemoteData:getValue())
				end,
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 4),
				}),
			}),
			["2RemoteData"] = Roact.createElement("ScrollingFrame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBarBackground),
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, -12, 0, 0),
				ClipsDescendants = true,
				BorderSizePixel = 0,
				ScrollBarImageColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar),
				ScrollBarThickness = 4,
				ScrollingDirection = Enum.ScrollingDirection.X,
				Visible = self.RemoteData,
			}, {
				-- UICorners dont work on ScrollingFrames :(
				--[[UICorner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),]]
				UIStroke = Roact.createElement("UIStroke", {
					Color = Theme:GetColor(Enum.StudioStyleGuideColor.Separator),
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Text = Roact.createElement("TextLabel", {
					Font = Enum.Font.Code,
					RichText = true,
					Text = self.RemoteData:map(function()
						if #self.props.RemoteData < RICHTEXT_CHARS_LIMIT then
							return self.props.RemoteData
						else
							local Result = (string.gsub((string.gsub(self.props.RemoteData, "<font color=\"#%w-\">", "")), "</font>", ""))
							if #Result > RICHTEXT_CHARS_LIMIT then
								return "<b><font color=\"#eb3434\">[Data is too long to be displayed]</font></b>"
							end

							return Result
						end
					end),
					TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.BrightText),
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ClipsDescendants = true,
				}, {
					Padding = Roact.createElement("UIPadding", {
						PaddingBottom = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 4),
					}),
				}),
			}),
			["3Separator"] = Roact.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Separator),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, -12, 0, 1),
				Visible = self.RemoteData:map(function(Visible)
					return not Visible
				end),
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0, 4),
				}),
			}),
			Padding = Roact.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 1),
			}),
			UIListLayout = Roact.createElement("UIListLayout"),
		})
	end)
end

local function DataChartItems(props)
	local ChartItems = {}

	local PercentOffset = 0
	for _, Arc in next, props.Arcs do
		PercentOffset -= Arc.Percent
		ChartItems[PercentOffset] = Roact.createElement(DataChartItem, {
			Arc = Arc,
			RemoteData = Arc.RemoteData,
		})
	end

	return Roact.createFragment(ChartItems)
end

local PacketChart = Roact.Component:extend("PacketChart")

function PacketChart:init()
	self.ArcsUpdated = Signal.new()
	self.ChartEnabled, self.SetChartEnabled = Roact.createBinding(false)

	self:setState({
		Arcs = {},
	})

end

function PacketChart:didMount()
	self.props.Signals.ProfilerFrameSelected:Connect(function(FrameData)
		local ArcData = {}

		for _, Packet in next, FrameData.Packets do
			local RemoteName = GetRemoteName(Packet.Remote, Packet.Data[1])
			local PacketSize = Packet.Size

			if not ArcData[RemoteName] then
				ArcData[RemoteName] = {
					Size = 0,
					Data = "",
				}
			end
			ArcData[RemoteName].Size += PacketSize
			ArcData[RemoteName].Data ..= "Packet data: " .. (Packet.Data and TableToSyntaxString(Packet.Data) or "[None]") .. "\n"
		end

		local Arcs = {}
		local TotalSize = FrameData.TotalSize
		for RemoteName, RemoteData in next, ArcData do
			local Percent = RemoteData.Size / TotalSize
			local Color = GetRemoteColor()
			table.insert(Arcs, {
				Name = RemoteName,
				DataSize = RemoteData.Size,
				Percent = Percent * 100,
				Color = Color,
				RemoteData = string.sub(RemoteData.Data, 1, -2),
			})
		end

		table.sort(Arcs, function(a, b)
			return a.Percent > b.Percent
		end)

		print(Arcs)
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
			Enabled = self.ChartEnabled,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}
	})[Packages.IsPlugin and "Plugin" or "Client"], {
		Holder = StudioTheme(function(Theme: StudioTheme)
			return Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Packages.IsPlugin and Vector2.new() or Vector2.new(1, 0),
				Position = Packages.IsPlugin and UDim2.new() or UDim2.new(1, 0, 0, 60),
				Size = Packages.IsPlugin and UDim2.fromScale(1, 1) or UDim2.fromOffset(450, 180),
				AutomaticSize = Packages.IsPlugin and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
			}, {
				Background = Roact.createElement("Frame", {
					BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
					BorderSizePixel = 0,
					ZIndex = 0,
					Size = UDim2.fromScale(1, 1),
				}),
				BackgroundCircle = Roact.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(PIE_CHART_SIZE, PIE_CHART_SIZE),
					Visible = not IsEditMode,
					Position = UDim2.fromOffset(4, 4),
				}, {
					-- Creating a separate background UI to avoid updating the pie chart when studio theme updates
					BackgroundUI = Roact.createElement("Frame", {
						BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.ScrollBarBackground),
						Size = UDim2.fromScale(1, 1),
						Visible = #self.state.Arcs > 0,
					}, {
						UICorner = Roact.createElement("UICorner", {
							CornerRadius = UDim.new(0, 4),
						}),
						UIStroke = Roact.createElement("UIStroke", {
							Color = Theme:GetColor(Enum.StudioStyleGuideColor.Separator),
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
					}),
					PacketCircle = Roact.createElement(PacketCircleArcs, {
						Arcs = self.state.Arcs,
					}),
				}),
				DataList = Roact.createElement("ScrollingFrame", {
					BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
					Size = UDim2.new(1, -PIE_CHART_SIZE - DATA_LIST_OFFSET, 1, 0),
					Position = UDim2.fromScale(1, 0),
					AnchorPoint = Vector2.new(1, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
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
						[Roact.Change.AbsoluteContentSize] = function(Rbx)
							Rbx.Parent.CanvasSize = UDim2.fromOffset(0, Rbx.AbsoluteContentSize.Y)
						end
					}),
					Items = Roact.createElement(DataChartItems, {
						Arcs = self.state.Arcs,
					})
				}),
				EditModeNotifier = Roact.createElement("TextLabel", {
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
				}),
			})
		end)
	})
end

return PacketChart