local RunService = game:GetService("RunService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local TOOLTIP_WIDTH = 220
local TOOLTIP_OFFSET = 14
local IS_EDIT_MODE = not RunService:IsRunning()

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local indexes = Vide.indexes
local read = Vide.read
local source = Vide.source

local function formatValue(value, unit)
	if unit == "bytes" then
		return string.format("%.2f KB", value / 1_000)
	end
	return string.format("%d %s", value, unit)
end

local function SpikeFrames(props)
	local profiler = props.Profiler
	local background
	local entries = source({})
	local mousePosition = source(Vector2.zero)
	local hoveredEntry = source(nil)
	local mouseOver = source(false)
	local selectedIndex = source(0)
	local hoveredIndex = 0

	local function refresh()
		entries(profiler:GetTopFrames(read(props.View), read(props.Limit)))
	end

	effect(function()
		read(props.View)
		read(props.Limit)
		selectedIndex(0)
		refresh()
	end)
	cleanup(Cleanup.disconnect(profiler.TopFramesChanged:Connect(refresh)))

	local function updatePointer(screenX)
		if background == nil then
			return
		end
		local localX = screenX - background.AbsolutePosition.X
		local width = background.AbsoluteSize.X
		local limit = read(props.Limit)
		local index = math.floor(localX / (width / limit)) + 1
		local entry = localX >= 0 and localX <= width and entries()[index] or nil

		mousePosition(Vector2.new(localX, 0))
		hoveredEntry(entry)
		hoveredIndex = index
	end

	return create("Frame")({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),

		InputBegan = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local entry = hoveredEntry()
			if entry then
				selectedIndex(hoveredIndex)
				profiler:SelectFrame(entry.Frame)
			end
		end,
		MouseEnter = function(x)
			if not IS_EDIT_MODE then
				mouseOver(true)
				updatePointer(x)
			end
		end,
		MouseMoved = function(x)
			if not IS_EDIT_MODE then
				updatePointer(x)
			end
		end,
		MouseLeave = function()
			mouseOver(false)
			hoveredEntry(nil)
		end,

		action(function(instance)
			background = instance
		end),

		indexes(entries, function(entry, index)
			return create("Frame")({
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = function()
					return read(props.Color)
				end,
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
				Position = function()
					return UDim2.fromScale((index - 1) / read(props.Limit), 1)
				end,
				Size = function()
					local height = math.min(entry().Size / read(props.MaxFrameSize), 1)
					return UDim2.new(1 / read(props.Limit), -2, height, 0)
				end,

				create("UIGradient")({
					Color = function()
						local color = read(props.Color)
						return ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color)
					end,
					Rotation = 90,
				}),
				create("TextLabel")({
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Font = Enum.Font.BuilderSansBold,
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.new(1, 0, 0, 16),
					Text = string.format("#%d", index),
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 11,
					TextStrokeTransparency = 0.6,
					ZIndex = 2,
				}),
			})
		end),

		create("Frame")({
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = function()
				return props.Theme("Border")
			end,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
		}),
		create("Frame")({
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Position = function()
				return UDim2.fromScale(math.max(selectedIndex() - 1, 0) / read(props.Limit), 0)
			end,
			Size = function()
				return UDim2.fromScale(1 / read(props.Limit), 1)
			end,
			Visible = function()
				return selectedIndex() > 0
			end,
			ZIndex = 3,
		}),
		create("Frame")({
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = function()
				return props.Theme("Tooltip")
			end,
			BorderSizePixel = 0,
			Position = function()
				local width = background and background.AbsoluteSize.X or 0
				return UDim2.fromOffset(
					math.max(8, math.min(mousePosition().X + TOOLTIP_OFFSET, width - TOOLTIP_WIDTH - 8)),
					4
				)
			end,
			Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0),
			Visible = function()
				return mouseOver() and hoveredEntry() ~= nil
			end,
			ZIndex = 10,

			create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			create("UIStroke")({
				Color = function()
					return props.Theme("Border")
				end,
				Transparency = 0.2,
			}),
			create("UIPadding")({
				PaddingBottom = UDim.new(0, 7),
				PaddingLeft = UDim.new(0, 9),
				PaddingRight = UDim.new(0, 9),
				PaddingTop = UDim.new(0, 7),
			}),
			create("TextLabel")({
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = Enum.Font.BuilderSans,
				Size = UDim2.fromScale(1, 0),
				Text = function()
					local entry = hoveredEntry()
					if entry == nil then
						return ""
					end
					local frame = profiler:GetViewFrame(entry.Frame, read(props.View))
					return string.format(
						"#%d  •  %d %s  •  %s  •  %.1fs ago",
						hoveredIndex,
						frame.PacketCount,
						read(props.EntryName),
						formatValue(entry.Size, read(props.Unit)),
						math.max(0, os.clock() - entry.Frame.Time)
					)
				end,
				TextColor3 = function()
					return props.Theme("BrightText")
				end,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 11,
			}),
		}),
		create("TextLabel")({
			BackgroundTransparency = 1,
			Font = Enum.Font.BuilderSans,
			Size = UDim2.fromScale(1, 1),
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

return SpikeFrames
