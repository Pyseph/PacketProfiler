local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local BuildChartData = require(PacketProfiler.Modules.ChartData)
local ChartResize = require(PacketProfiler.Components.ChartResize)
local PacketChartItems = require(PacketProfiler.Components.PacketChartItems)
local PacketCircleArcs = require(PacketProfiler.Components.PacketCircleArcs)
local SpikeInspector = require(PacketProfiler.Components.SpikeInspector)
local StudioWidget = require(PacketProfiler.Components.StudioWidget)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local PIE_SIZE = 112
local HEADER_HEIGHT = 36
local IS_EDIT_MODE = not RunService:IsRunning()

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source
local switch = Vide.switch

local function PacketChartContents(props, target)
	local state = props.State
	local profiler = state.Profiler
	local arcs = source({})
	local hasSelection = source(false)
	local selectedArc = source(nil)
	local scrollBarVisible = source(false)
	local resize = ChartResize()

	local function updateSelection(frame)
		arcs(frame and BuildChartData(frame) or {})
		hasSelection(frame ~= nil)
		selectedArc(nil)
	end

	if profiler.SelectedFrame then
		updateSelection(profiler:GetViewFrame(profiler.SelectedFrame, state.View()))
	end
	cleanup(Cleanup.disconnect(profiler.SelectionChanged:Connect(updateSelection)))

	local function title()
		local layer = state.GetActiveLayer()
		local prefix = if state.Mode() == "spikes" then "Top spikes" else "Frame details"
		if #state.Layers() <= 1 then
			return prefix
		end
		return string.format("%s  ·  %s", prefix, layer and layer.Name or profiler:GetAllViewName())
	end

	local function holder(parent)
		return create("Frame")({
			AnchorPoint = if Packages.IsPlugin then Vector2.zero else Vector2.new(1, 0),
			BackgroundColor3 = function()
				return props.Theme("MainBackground")
			end,
			BorderSizePixel = 0,
			Parent = parent,
			Position = if Packages.IsPlugin then UDim2.new() else UDim2.new(1, -10, 0, 118),
			Size = if Packages.IsPlugin then UDim2.fromScale(1, 1) else resize.Size,

			if not Packages.IsPlugin
				then {
					create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
					action(function(instance)
						resize.SetTarget(instance)
					end),
				}
				else nil,
			create("UIStroke")({
				Color = function()
					return props.Theme("Border")
				end,
				Transparency = 0.15,
			}),
			create("Frame")({
				BackgroundColor3 = function()
					return props.Theme("Item")
				end,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),

				create("TextLabel")({
					BackgroundTransparency = 1,
					Font = Enum.Font.BuilderSansBold,
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -24, 1, 0),
					Text = title,
					TextColor3 = function()
						return props.Theme("BrightText")
					end,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),
			create("Frame")({
				BackgroundColor3 = function()
					return props.Theme("ScrollBarBackground")
				end,
				BackgroundTransparency = 0.35,
				Position = UDim2.fromOffset(12, HEADER_HEIGHT + 12),
				Size = UDim2.fromOffset(PIE_SIZE, PIE_SIZE),
				Visible = function()
					return state.Mode() ~= "spikes" and hasSelection() and #arcs() > 0 and not IS_EDIT_MODE
				end,

				create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
				PacketCircleArcs({
					Arcs = arcs,
					OnArcClicked = function(name)
						selectedArc(name)
					end,
				}),
			}),
			create("ScrollingFrame")({
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				Position = function()
					return if state.Mode() == "spikes"
						then UDim2.fromOffset(8, HEADER_HEIGHT + 4)
						else UDim2.fromOffset(PIE_SIZE + 28, HEADER_HEIGHT + 4)
				end,
				ScrollBarImageColor3 = function()
					return props.Theme("Light")
				end,
				ScrollBarThickness = 5,
				Size = function()
					return if state.Mode() == "spikes"
						then UDim2.new(1, -16, 1, -HEADER_HEIGHT - 8)
						else UDim2.new(1, -PIE_SIZE - 34, 1, -HEADER_HEIGHT - 8)
				end,
				Visible = function()
					return state.Mode() == "spikes" or (hasSelection() and #arcs() > 0 and not IS_EDIT_MODE)
				end,

				action(function(instance)
					local function update()
						scrollBarVisible(instance.AbsoluteCanvasSize.Y > instance.AbsoluteSize.Y)
					end
					update()
					cleanup(instance:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(update))
					cleanup(instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
				end),
				create("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					action(function(layout)
						local function updateCanvas()
							local scrollingFrame = layout.Parent
							if scrollingFrame then
								scrollingFrame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
							end
						end
						cleanup(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
					end),
				}),
				create("UIPadding")({
					PaddingBottom = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 8),
				}),
				switch(state.Mode)({
					timeline = function()
						return PacketChartItems({
							Arcs = arcs,
							ScrollBarVisible = scrollBarVisible,
							SelectedArc = selectedArc,
							Theme = props.Theme,
							Unit = state.Unit,
						})
					end,
					spikes = function()
						return SpikeInspector({
							Color = state.ActiveColor,
							Limit = state.TopCount,
							Profiler = profiler,
							ScrollBarVisible = scrollBarVisible,
							Theme = props.Theme,
							Unit = state.Unit,
							View = state.View,
						})
					end,
				}),
			}),
			create("TextLabel")({
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSans,
				Position = UDim2.fromOffset(20, HEADER_HEIGHT),
				Size = UDim2.new(1, -40, 1, -HEADER_HEIGHT),
				Text = function()
					if IS_EDIT_MODE then
						return "Run the experience to inspect traffic"
					elseif hasSelection() then
						return "No packets in this layer"
					end
					return "Select a frame to inspect its packets"
				end,
				TextColor3 = function()
					return props.Theme("SubText")
				end,
				TextSize = 14,
				Visible = function()
					return state.Mode() ~= "spikes" and (IS_EDIT_MODE or not hasSelection() or #arcs() == 0)
				end,
			}),
		})
	end

	return holder(target)
end

local function PacketChart(props)
	local state = props.State
	local parent
	if Packages.IsPlugin then
		parent = StudioWidget({
			DefaultSize = Vector2.new(520, 420),
			Enabled = state.ChartEnabled,
			InitialDockState = Enum.InitialDockState.Float,
			MinimumSize = Vector2.new(340, 180),
			OnEnabled = state.SetChartEnabled,
			Plugin = props.Plugin,
			WidgetId = "PacketChart",
			WidgetTitle = "Packet details",
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
	else
		parent = create("ScreenGui")({
			Enabled = state.ChartEnabled,
			IgnoreGuiInset = true,
			Parent = Players.LocalPlayer.PlayerGui,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
	end
	Vide.effect(function()
		if state.ChartEnabled() then
			cleanup(Vide.mount(function()
				PacketChartContents(props, parent)
			end))
		end
	end)
	return parent
end

return PacketChart
