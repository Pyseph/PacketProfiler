local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local AnimatedButton = require(PacketProfiler.Components.AnimatedButton)
local LayerTabs = require(PacketProfiler.Components.LayerTabs)
local PacketFrames = require(PacketProfiler.Components.PacketFrames)
local SpikeFrames = require(PacketProfiler.Components.SpikeFrames)

local CONTROL_ROW_HEIGHT = 40
local GRAPH_HEIGHT = 70
local TITLE_WIDTH = 106
local HEADER_GAP = 8
local CONTROL_GAP = 4
local PAUSE_WIDTH = 72
local CLOSE_WIDTH = 28
local MODE_WIDTH = 78
local TOP_COUNT_WIDTH = 58

local create = Vide.create
local show = Vide.show
local switch = Vide.switch

local function scaleButtonWidth(text)
	return TextService:GetTextSize(text, 13, Enum.Font.BuilderSansMedium, Vector2.new(300, 26)).X + 24
end

local function formatScale(value, unit)
	if unit == "bytes" then
		return string.format("%g KB max", value / 1_000)
	end
	return string.format("%g %s", value, unit)
end

local function PacketProfilerView(props)
	local state = props.State
	local profiler = state.Profiler
	local target = Packages.IsPlugin and game:GetService("CoreGui") or Players.LocalPlayer.PlayerGui

	local function scaleText()
		return formatScale(state.MaxFrameSize(), state.Unit())
	end

	local function controlsWidth()
		local topCountWidth = if state.Mode() == "spikes" then TOP_COUNT_WIDTH + CONTROL_GAP else 0
		return scaleButtonWidth(scaleText()) + MODE_WIDTH + topCountWidth + PAUSE_WIDTH + CLOSE_WIDTH + CONTROL_GAP * 3
	end

	return create("ScreenGui")({
		DisplayOrder = 10,
		Enabled = state.ProfilerEnabled,
		IgnoreGuiInset = true,
		Parent = target,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		create("Frame")({
			BackgroundColor3 = function()
				return props.Theme("MainBackground")
			end,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, CONTROL_ROW_HEIGHT + GRAPH_HEIGHT),

			create("Frame")({
				BackgroundColor3 = function()
					return props.Theme("Item")
				end,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, CONTROL_ROW_HEIGHT),
				ZIndex = 3,

				create("Frame")({
					BackgroundColor3 = state.ActiveColor,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(3, CONTROL_ROW_HEIGHT),
				}),
				create("TextLabel")({
					BackgroundTransparency = 1,
					Font = Enum.Font.BuilderSansBold,
					Position = UDim2.fromOffset(14, 0),
					Size = UDim2.fromOffset(TITLE_WIDTH - 14, CONTROL_ROW_HEIGHT),
					Text = "Packet Profiler",
					TextColor3 = function()
						return props.Theme("BrightText")
					end,
					TextSize = 14,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				show(function()
					return #state.Layers() > 1
				end, function()
					return LayerTabs({
						AllViewName = state.AllViewName,
						Layers = state.Layers,
						OnViewChanged = function(view)
							profiler:SetView(view)
						end,
						Position = UDim2.fromOffset(TITLE_WIDTH, 7),
						Size = function()
							return UDim2.new(1, -(TITLE_WIDTH + controlsWidth() + HEADER_GAP * 2), 0, 26)
						end,
						Theme = props.Theme,
						View = state.View,
					})
				end),
				create("Frame")({
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -8, 0, CONTROL_ROW_HEIGHT / 2),
					Size = function()
						return UDim2.fromOffset(controlsWidth(), 28)
					end,

					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						Padding = UDim.new(0, CONTROL_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					AnimatedButton({
						AccentColor = function()
							return props.Theme("Light")
						end,
						LayoutOrder = 1,
						OnClick = state.CycleScale,
						Size = function()
							return UDim2.fromOffset(scaleButtonWidth(scaleText()), 26)
						end,
						Text = scaleText,
						TextColor = function()
							return props.Theme("MainText")
						end,
						TextTruncate = Enum.TextTruncate.None,
					}),
					show(function()
						return state.Mode() == "spikes"
					end, function()
						return AnimatedButton({
							AccentColor = state.ActiveColor,
							LayoutOrder = 2,
							OnClick = state.CycleTopCount,
							Size = UDim2.fromOffset(TOP_COUNT_WIDTH, 26),
							Text = function()
								return string.format("Top %d", state.TopCount())
							end,
							TextColor = function()
								return props.Theme("BrightText")
							end,
						})
					end),
					AnimatedButton({
						AccentColor = state.ActiveColor,
						LayoutOrder = 3,
						OnClick = function()
							state.SetMode(if state.Mode() == "timeline" then "spikes" else "timeline")
						end,
						Selected = function()
							return state.Mode() == "spikes"
						end,
						Size = UDim2.fromOffset(MODE_WIDTH, 26),
						Text = function()
							return if state.Mode() == "spikes" then "Timeline" else "Top spikes"
						end,
						TextColor = function()
							return props.Theme("BrightText")
						end,
					}),
					AnimatedButton({
						AccentColor = function()
							return if state.Paused() then Color3.fromHex("#F2B84B") else Color3.fromHex("#45C98A")
						end,
						LayoutOrder = 4,
						OnClick = function()
							profiler:SetPaused(not profiler.Paused)
						end,
						Selected = true,
						SelectedTransparency = 0.8,
						Size = UDim2.fromOffset(PAUSE_WIDTH, 26),
						Text = function()
							return if state.Paused() then "Paused" else "Live"
						end,
						TextColor = function()
							return props.Theme("BrightText")
						end,
					}),
					AnimatedButton({
						AccentColor = function()
							return props.Theme("Light")
						end,
						LayoutOrder = 5,
						OnClick = function()
							state.SetProfilerEnabled(false)
						end,
						Size = UDim2.fromOffset(CLOSE_WIDTH, 26),
						Text = "×",
						TextColor = function()
							return props.Theme("MainText")
						end,
						TextSize = 18,
					}),
				}),
				create("Frame")({
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = function()
						return props.Theme("Border")
					end,
					BackgroundTransparency = 0.3,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 1),
				}),
			}),
			create("Frame")({
				BackgroundColor3 = function()
					return props.Theme("ScriptBackground")
				end,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, CONTROL_ROW_HEIGHT),
				Size = UDim2.new(1, 0, 0, GRAPH_HEIGHT),

				create("UIPadding")({
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 6),
				}),
				switch(state.Mode)({
					timeline = function()
						return PacketFrames({
							Color = state.ActiveColor,
							EntryName = state.EntryName,
							MaxFrameSize = state.MaxFrameSize,
							Profiler = profiler,
							Theme = props.Theme,
							Unit = state.Unit,
							View = state.View,
						})
					end,
					spikes = function()
						return SpikeFrames({
							Color = state.ActiveColor,
							EntryName = state.EntryName,
							Limit = state.TopCount,
							MaxFrameSize = state.MaxFrameSize,
							Profiler = profiler,
							Theme = props.Theme,
							Unit = state.Unit,
							View = state.View,
						})
					end,
				}),
			}),
		}),
	})
end

return PacketProfilerView
