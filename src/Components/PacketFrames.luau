local RunService = game:GetService("RunService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local TimelineRenderer = require(PacketProfiler.Components.TimelineRenderer)

local TOOLTIP_WIDTH = 190
local TOOLTIP_OFFSET = 14
local IS_EDIT_MODE = not RunService:IsRunning()

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local effect = Vide.effect
local read = Vide.read
local source = Vide.source

local function formatValue(value, unit)
	if unit == "bytes" then
		return string.format("%.2f KB", value / 1_000)
	end
	return string.format("%d %s", value, unit)
end

local function PacketFrames(props)
	local profiler = props.Profiler
	local maxFrames = profiler:GetMaxFrames()
	local background
	local mousePosition = source(Vector2.zero)
	local hoveredFrame = source(nil)
	local selectedIndex = source(0)
	local mouseOver = source(false)
	local hoveredIndex = 0
	local renderer

	local function updateBars()
		renderer:Render(profiler, read(props.View), read(props.MaxFrameSize), read(props.Color))
	end

	renderer = TimelineRenderer.new(maxFrames, updateBars)

	effect(function()
		read(props.View)
		read(props.MaxFrameSize)
		updateBars()
	end)
	cleanup(Cleanup.disconnect(profiler.FrameBatchCommitted:Connect(function(frames)
		renderer:CommitBatch(profiler, frames, read(props.View), read(props.MaxFrameSize), read(props.Color))
	end)))

	local function updatePointer(screenX)
		if background == nil then
			return
		end

		local localX = screenX - background.AbsolutePosition.X
		local width = background.AbsoluteSize.X
		local frameWidth = width / maxFrames
		local index = math.clamp(maxFrames - math.floor(localX / frameWidth), 1, maxFrames)
		local frame = localX >= 0 and localX < width and renderer:GetFrame(index) or nil

		mousePosition(Vector2.new(localX, 0))
		hoveredFrame(frame)
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
			local frame = hoveredFrame()
			if frame then
				selectedIndex(hoveredIndex)
				profiler:SetPaused(true)
				profiler:SelectFrame(frame)
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
			hoveredFrame(nil)
		end,

		action(function(instance)
			background = instance
		end),

		renderer:Create(),

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
				return UDim2.fromScale(1 - selectedIndex() / maxFrames, 0)
			end,
			Size = UDim2.fromScale(1 / maxFrames, 1),
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
				return mouseOver() and hoveredFrame() ~= nil
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
					local frame = hoveredFrame()
					if frame == nil then
						return ""
					end
					local viewFrame = profiler:GetViewFrame(frame, read(props.View))
					return string.format(
						"%d %s  •  %s",
						viewFrame.PacketCount,
						read(props.EntryName),
						formatValue(viewFrame.TotalSize, read(props.Unit))
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
			Text = "Run the experience to begin profiling",
			TextColor3 = function()
				return props.Theme("SubText")
			end,
			TextSize = 14,
			Visible = IS_EDIT_MODE,
		}),
	})
end

return PacketFrames
