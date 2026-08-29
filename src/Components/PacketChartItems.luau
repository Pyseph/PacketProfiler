local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local action = Vide.action
local create = Vide.create
local effect = Vide.effect
local indexes = Vide.indexes
local read = Vide.read
local source = Vide.source
local spring = Vide.spring

local function getSizeUnit(value, unit)
	if unit ~= "bytes" then
		return value, unit
	elseif value < 1_000 then
		return value, "bytes"
	elseif value < 1_000_000 then
		return value / 1_000, "kilobytes"
	end
	return value / 1_000_000, "megabytes"
end

local function DataChartItem(props)
	local expanded = source(false)
	local containerSize = source(Vector2.zero)
	local highlightTransparency = spring(function()
		local selected = props.SelectedArc and props.SelectedArc() == props.Arc().Name
		return if selected then 0.72 else 1
	end, 0.16, 1)

	if props.SelectedArc then
		effect(function()
			local selected = props.SelectedArc()
			if selected ~= nil and selected == props.Arc().Name then
				expanded(true)
			end
		end)
	end

	return create("Frame")({
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),

		create("Frame")({
			BackgroundColor3 = function()
				return props.Arc().Color
			end,
			BackgroundTransparency = highlightTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}),
		create("TextButton")({
			AutoButtonColor = false,
			AutoLocalize = false,
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Position = UDim2.fromOffset(18, 0),
			RichText = true,
			Size = UDim2.new(1, -18, 0, 20),
			Text = function()
				local arc = props.Arc()
				local value, unit = getSizeUnit(arc.DataSize, read(props.Unit))
				return string.format(
					'<font color="#%s"><b>%s</b></font>: %.1f%%, %g %s',
					arc.Color:ToHex(),
					arc.Name,
					arc.Percent,
					value,
					unit
				)
			end,
			TextColor3 = function()
				return props.Theme("BrightText")
			end,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,

			Activated = function()
				expanded(not expanded())
			end,

			create("UIPadding")({ PaddingBottom = UDim.new(0, 4) }),
		}),
		create("ImageLabel")({
			BackgroundTransparency = 1,
			Image = function()
				return if expanded() then "rbxassetid://18699144520" else "rbxassetid://18699113012"
			end,
			ImageColor3 = function()
				return props.Theme("BrightText")
			end,
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 3,
		}),
		create("Frame")({
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 24),
			Size = function()
				return UDim2.new(1, read(props.ScrollBarVisible) and -12 or 0, 0, 0)
			end,

			action(function(instance)
				containerSize(instance.AbsoluteSize)
				Vide.cleanup(instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					containerSize(instance.AbsoluteSize)
				end))
			end),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			indexes(function()
				return props.Arc().RemoteData
			end, function(remoteData, index)
				return {
					create("TextButton")({
						AutoButtonColor = false,
						AutoLocalize = false,
						BackgroundTransparency = 1,
						Font = Enum.Font.SourceSans,
						LayoutOrder = index * 2,
						RichText = true,
						Selectable = false,
						Size = UDim2.new(1, 0, 0, 20),
						Text = function()
							return remoteData().Name
						end,
						TextColor3 = function()
							return props.Theme("BrightText")
						end,
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = expanded,

						create("UIPadding")({ PaddingBottom = UDim.new(0, 4) }),
					}),
					create("ScrollingFrame")({
						AutomaticCanvasSize = Enum.AutomaticSize.X,
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = function()
							return props.Theme("ScrollBarBackground")
						end,
						BorderSizePixel = 0,
						ClipsDescendants = true,
						LayoutOrder = index * 2 + 1,
						ScrollBarImageColor3 = function()
							return props.Theme("ScrollBar")
						end,
						ScrollBarThickness = 4,
						ScrollingDirection = Enum.ScrollingDirection.X,
						Size = UDim2.new(1, -12, 0, 0),
						Visible = expanded,

						create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
						create("UIStroke")({
							Color = function()
								return props.Theme("DropShadow")
							end,
							LineJoinMode = Enum.LineJoinMode.Round,
							Transparency = 0.5,
						}),
						create("TextLabel")({
							AutomaticSize = Enum.AutomaticSize.XY,
							AutoLocalize = false,
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Font = Enum.Font.Code,
							RichText = true,
							Size = UDim2.fromScale(1, 1),
							Text = function()
								return remoteData().Packet
							end,
							TextColor3 = function()
								return props.Theme("BrightText")
							end,
							TextSize = 12,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,

							create("UIPadding")({
								PaddingBottom = UDim.new(0, 8),
								PaddingLeft = UDim.new(0, 4),
								PaddingRight = UDim.new(0, 8),
								PaddingTop = UDim.new(0, 4),
							}),
						}),
					}),
				}
			end),
		}),
		create("Frame")({
			BackgroundColor3 = function()
				return props.Theme("DropShadow")
			end,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 26),
			Size = function()
				return UDim2.fromOffset(1, containerSize().Y)
			end,
			ZIndex = 2,
		}),
	})
end

local function PacketChartItems(props)
	local arcs = if type(props.Arcs) == "function"
		then props.Arcs
		else function()
			return props.Arcs
		end

	return indexes(arcs, function(arc)
		return DataChartItem({
			Arc = arc,
			ScrollBarVisible = props.ScrollBarVisible,
			SelectedArc = props.SelectedArc,
			Theme = props.Theme,
			Unit = props.Unit,
		})
	end)
end

return PacketChartItems
