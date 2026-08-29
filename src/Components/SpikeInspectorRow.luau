local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local PacketChartItems = require(PacketProfiler.Components.PacketChartItems)

local create = Vide.create
local indexes = Vide.indexes
local read = Vide.read
local show = Vide.show

local function formatValue(value, unit)
	if unit ~= "bytes" then
		return string.format("%g %s", value, unit)
	elseif value < 1_000 then
		return string.format("%g bytes", value)
	elseif value < 1_000_000 then
		return string.format("%.2f KB", value / 1_000)
	end
	return string.format("%.2f MB", value / 1_000_000)
end

local function contributorRows(props)
	return indexes(function()
		local rows = {}
		local arcs = read(props.Arcs)
		for index = 1, math.min(3, #arcs) do
			rows[index] = arcs[index]
		end
		return rows
	end, function(arc, index)
		return create("Frame")({
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 18),

			create("Frame")({
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = function()
					return arc().Color
				end,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 9),
				Size = UDim2.fromOffset(6, 6),
				create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			}),
			create("TextLabel")({
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSans,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -116, 1, 0),
				Text = function()
					return arc().Name
				end,
				TextColor3 = function()
					return props.Theme("MainText")
				end,
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			create("TextLabel")({
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSansMedium,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(96, 18),
				Text = function()
					return formatValue(arc().DataSize, read(props.Unit))
				end,
				TextColor3 = function()
					return props.Theme("SubText")
				end,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end)
end

local function SpikeInspectorRow(props)
	return create("Frame")({
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = function()
			return if read(props.Selected) then props.Theme("Item") else props.Theme("MainBackground")
		end,
		BorderSizePixel = 0,
		LayoutOrder = props.Rank,
		Size = UDim2.fromScale(1, 0),

		create("UICorner")({ CornerRadius = UDim.new(0, 7) }),
		create("UIStroke")({
			Color = function()
				return if read(props.Selected) then read(props.Color) else props.Theme("Border")
			end,
			Transparency = function()
				return if read(props.Selected) then 0.15 else 0.45
			end,
		}),
		create("UIPadding")({
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
		}),
		create("UIListLayout")({
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("TextButton")({
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 38),
			Text = "",
			Activated = props.OnToggle,

			create("TextLabel")({
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSansBold,
				Size = UDim2.fromOffset(38, 24),
				Text = string.format("#%d", props.Rank),
				TextColor3 = function()
					return read(props.Color)
				end,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			create("TextLabel")({
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSansMedium,
				Position = UDim2.fromOffset(40, 0),
				Size = UDim2.new(1, -66, 0, 20),
				Text = function()
					local entry = read(props.Entry)
					local frame = read(props.ViewFrame)
					return string.format(
						"%s  ·  %d packets  ·  %.1fs ago",
						formatValue(entry.Size, read(props.Unit)),
						frame.PacketCount,
						math.max(0, os.clock() - entry.Frame.Time)
					)
				end,
				TextColor3 = function()
					return props.Theme("BrightText")
				end,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			create("TextLabel")({
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSansBold,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(20, 20),
				Text = function()
					return if read(props.Expanded) then "−" else "+"
				end,
				TextColor3 = function()
					return props.Theme("SubText")
				end,
				TextSize = 16,
			}),
			create("Frame")({
				BackgroundColor3 = function()
					return props.Theme("ScrollBarBackground")
				end,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(40, 28),
				Size = UDim2.new(1, -66, 0, 4),
				create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				create("Frame")({
					BackgroundColor3 = function()
						return read(props.Color)
					end,
					BorderSizePixel = 0,
					Size = function()
						return UDim2.fromScale(
							math.clamp(read(props.Entry).Size / math.max(read(props.MaxSize), 1), 0, 1),
							1
						)
					end,
					create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				}),
			}),
		}),
		show(function()
			return not read(props.Expanded)
		end, function()
			return create("Frame")({
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = function()
					local height = math.max(1, math.min(3, #read(props.Arcs))) * 18
					return UDim2.new(1, 0, 0, height)
				end,
				create("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
				contributorRows(props),
			})
		end),
		show(function()
			return read(props.Expanded)
		end, function()
			return create("Frame")({
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				create("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
				PacketChartItems({
					Arcs = props.Arcs,
					ScrollBarVisible = props.ScrollBarVisible,
					Theme = props.Theme,
					Unit = props.Unit,
				}),
			})
		end),
	})
end

return SpikeInspectorRow
