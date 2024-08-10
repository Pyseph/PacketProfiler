local PacketProfiler = script.Parent.Parent
local Components = PacketProfiler.Components
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)

local StudioTheme = require(Components.StudioTheme)

local function GetSizeUnit(Value: number): (number, string)
	if Value < 1000 then
		return Value, "bytes"
	elseif Value < 1000 * 1000 then
		return Value / 1000, "kilobytes"
	else
		return Value / (1000 * 1000), "megabytes"
	end
end

local DataChartItem = Roact.Component:extend("DataChartItem")

function DataChartItem:init()
	self.RemoteData, self.ShowRemoteData = Roact.createBinding(false)
	self.Size, self.SetSize = Roact.createBinding(Vector2.zero)
end

function DataChartItem:render()
	local Arc = self.props.Arc
	local RemoteCalls = {}
	for Index, RemoteData in self.props.RemoteData do
		RemoteCalls[Index] = StudioTheme(function(Theme)
			local TitleIndex = Index * 2
			local ContainerIndex = Index * 2 + 1

			local Title = Roact.createElement("TextButton", {
				AutoLocalize = false,
				LayoutOrder = TitleIndex,
				Font = Enum.Font.SourceSans,
				Text = RemoteData.Name,
				RichText = true,
				TextColor3 = Theme:GetColor("BrightText"),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 20),
				Visible = self.RemoteData,
				Selectable = false,
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 4),
				}),
			})
			local CodeContainer = Roact.createElement("ScrollingFrame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				LayoutOrder = ContainerIndex,
				BackgroundColor3 = Theme:GetColor("ScrollBarBackground"),
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, -12, 0, 0),
				ClipsDescendants = true,
				BorderSizePixel = 0,
				ScrollBarImageColor3 = Theme:GetColor("ScrollBar"),
				ScrollBarThickness = 4,
				ScrollingDirection = Enum.ScrollingDirection.X,
				Visible = self.RemoteData,
				[Roact.Ref] = function(ScrollingFrame)
					if ScrollingFrame ~= nil then
						-- This is a workaround for the fact that the UICorners don't work properly on ScrollingFrames.
						-- If you try creating a UICorner normally, it refuses to render. Using task.defer also doesn't work.
						-- ¯\_(ツ)_/¯
						task.delay(0.1, function()
							local UICorner = Instance.new("UICorner")
							UICorner.CornerRadius = UDim.new(0, 4)
							UICorner.Parent = ScrollingFrame
						end)
					end
				end,
			}, {
				UIStroke = Roact.createElement("UIStroke", {
					Color = Theme:GetColor("DropShadow"),
					LineJoinMode = Enum.LineJoinMode.Round,
					Transparency = 0.5,
				}),
				Text = Roact.createElement("TextLabel", {
					AutoLocalize = false,
					Font = Enum.Font.Code,
					RichText = true,
					Text = RemoteData.Packet,
					TextColor3 = Theme:GetColor("BrightText"),
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
						PaddingRight = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 4),
						PaddingTop = UDim.new(0, 4),
					}),
				}),
			})

			return Roact.createFragment({Title, CodeContainer})
		end)
	end

	return StudioTheme(function(Theme)
		return Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			["Information"] = Roact.createElement("TextButton", {
				AutoLocalize = false,
				Font = Enum.Font.SourceSans,
				Text = string.format("<font color=\"#%s\"><b>%s</b></font>: %.1f%%, %d %s", Arc.Color:ToHex(), Arc.Name, Arc.Percent, GetSizeUnit(Arc.DataSize)),
				RichText = true,
				TextColor3 = Theme:GetColor("BrightText"),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -18, 0, 20),
				Position = UDim2.fromOffset(18, 0),
				ZIndex = 3,
				[Roact.Event.Activated] = function()
					self.ShowRemoteData(not self.RemoteData:getValue())
				end,
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 4),
				}),
			}),
			Chevron = Roact.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				Image = self.RemoteData:map(function(RemoteData)
					return RemoteData and "rbxassetid://18699144520" or "rbxassetid://18699113012"
				end),
				ImageColor3 = Theme:GetColor("BrightText"),
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.fromOffset(0, 2),
			}),
			Container = Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = self.props.ScrollBarChanged:map(function(Data)
					return UDim2.new(1, Data.Visible and -12 or 0, 0, 0)
				end),
				Position = UDim2.fromOffset(8, 24),
				Transparency = 1,
				[Roact.Change.AbsoluteSize] = function(Rbx)
					self.SetSize(Rbx.AbsoluteSize)
				end,
			}, {
				RemoteData = Roact.createFragment(RemoteCalls),
				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					Padding = UDim.new(0, 0),
				}),
			}),
			Divider = Roact.createElement("Frame", {
				BackgroundColor3 = Theme:GetColor("DropShadow"),
				Transparency = 0.5,
				BorderSizePixel = 0,
				Size = self.Size:map(function(Size)
					return UDim2.new(0, 1, 0, Size.Y)
				end),
				Position = UDim2.fromOffset(0, 26),
				ZIndex = 2,
			}),
		})
	end)
end

local function DataChartItems(props)
	local ChartItems = {}

	local PercentOffset = 0
	for _, Arc in props.Arcs do
		PercentOffset -= Arc.Percent
		ChartItems[PercentOffset] = Roact.createElement(DataChartItem, {
			Arc = Arc,
			RemoteData = Arc.RemoteData,
			ScrollBarChanged = props.ScrollBarChanged,
		})
	end

	return Roact.createFragment(ChartItems)
end

return DataChartItems