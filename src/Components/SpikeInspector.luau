local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local AnimatedButton = require(PacketProfiler.Components.AnimatedButton)
local SpikeInspectorRow = require(PacketProfiler.Components.SpikeInspectorRow)
local BuildChartData = require(PacketProfiler.Modules.ChartData)

local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local effect = Vide.effect
local indexes = Vide.indexes
local read = Vide.read
local source = Vide.source

local function SpikeInspector(props)
	local profiler = props.Profiler
	local entries = source({})
	local expanded = source({})
	local frozen = source(false)
	local selectedFrame = source(profiler.SelectedFrame)

	local function refresh(force)
		if not force and frozen() then
			return
		end
		entries(profiler:GetTopFrames(read(props.View), read(props.Limit)))
	end

	effect(function()
		read(props.View)
		read(props.Limit)
		expanded({})
		frozen(false)
		refresh(true)
	end)
	cleanup(profiler.TopFramesChanged:Connect(refresh))
	cleanup(profiler.SelectionChanged:Connect(function()
		selectedFrame(profiler.SelectedFrame)
	end))

	local function allExpanded()
		local currentEntries = entries()
		if #currentEntries == 0 then
			return false
		end
		local currentExpanded = expanded()
		for _, entry in currentEntries do
			if not currentExpanded[entry.Frame] then
				return false
			end
		end
		return true
	end

	local function setAllExpanded(value)
		local nextExpanded = {}
		if value then
			for _, entry in entries() do
				nextExpanded[entry.Frame] = true
			end
		end
		expanded(nextExpanded)
	end

	return create("Frame")({
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),

		create("UIListLayout")({
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("Frame")({
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 28),

			create("TextLabel")({
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSans,
				Size = UDim2.new(1, -190, 1, 0),
				Text = function()
					return string.format("%d retained spikes · largest first", #entries())
				end,
				TextColor3 = function()
					return props.Theme("SubText")
				end,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			create("Frame")({
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(184, 26),

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 5),
				}),
				AnimatedButton({
					AccentColor = function()
						return props.Theme("Light")
					end,
					LayoutOrder = 1,
					OnClick = function()
						setAllExpanded(not allExpanded())
					end,
					Size = UDim2.fromOffset(96, 24),
					Text = function()
						return if allExpanded() then "Collapse all" else "Expand all"
					end,
					TextColor = function()
						return props.Theme("MainText")
					end,
					TextSize = 12,
				}),
				AnimatedButton({
					AccentColor = props.Color,
					LayoutOrder = 2,
					OnClick = function()
						frozen(not frozen())
						if not frozen() then
							refresh(true)
						end
					end,
					Selected = frozen,
					Size = UDim2.fromOffset(80, 24),
					Text = function()
						return if frozen() then "Frozen" else "Live order"
					end,
					TextColor = function()
						return props.Theme("BrightText")
					end,
					TextSize = 12,
				}),
			}),
		}),
		indexes(entries, function(entry, rank)
			local arcs = derive(function()
				return BuildChartData(profiler:GetViewFrame(entry().Frame, read(props.View)))
			end)
			local viewFrame = derive(function()
				return profiler:GetViewFrame(entry().Frame, read(props.View))
			end)
			local isExpanded = function()
				return expanded()[entry().Frame] == true
			end

			return SpikeInspectorRow({
				Arcs = arcs,
				Color = props.Color,
				Entry = entry,
				Expanded = isExpanded,
				MaxSize = function()
					local first = entries()[1]
					return first and first.Size or 1
				end,
				OnToggle = function()
					local frame = entry().Frame
					local nextExpanded = table.clone(expanded())
					nextExpanded[frame] = not nextExpanded[frame]
					expanded(nextExpanded)
					selectedFrame(frame)
					profiler:SelectFrame(frame)
				end,
				Rank = rank,
				ScrollBarVisible = props.ScrollBarVisible,
				Selected = function()
					return selectedFrame() == entry().Frame
				end,
				Theme = props.Theme,
				Unit = props.Unit,
				ViewFrame = viewFrame,
			})
		end),
		create("TextLabel")({
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 100),
			Text = "No spikes recorded in this view yet",
			TextColor3 = function()
				return props.Theme("SubText")
			end,
			TextSize = 14,
			Visible = function()
				return #entries() == 0
			end,
		}),
	})
end

return SpikeInspector
