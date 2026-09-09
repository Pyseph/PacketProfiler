local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local action = Vide.action
local cleanup = Vide.cleanup
local create = Vide.create
local derive = Vide.derive
local effect = Vide.effect
local indexes = Vide.indexes
local read = Vide.read
local source = Vide.source

local function lerp(a, b, alpha)
	return a + (b - a) * alpha
end

local function CircleArc(props)
	return create("ImageLabel")({
		BackgroundTransparency = 1,
		Image = "rbxassetid://3587367081",
		ImageColor3 = function()
			local segment = props.Segment()
			local percent = props.Highlighted()
			if percent >= segment.StartPercent and percent < segment.EndPercent then
				return segment.Color:Lerp(Color3.new(1, 1, 1), 0.5)
			end
			return segment.Color
		end,
		Position = function()
			return UDim2.fromScale(if props.Segment().Side == "Left" then 0 else -1, 0)
		end,
		Size = UDim2.fromScale(2, 1),
		ZIndex = function()
			return props.Segment().ZIndex
		end,

		create("UIGradient")({
			Rotation = function()
				local segment = props.Segment()
				local alpha = props.AnimationAlpha()
				if segment.Side == "Left" then
					local visible = lerp(0, segment.VisiblePercent, math.clamp(alpha * 2, 0, 1))
					return -3.6 * visible + 180
				end
				local visible = lerp(0, segment.VisiblePercent - 50, math.clamp(alpha * 2 - 1, 0, 1))
				return lerp(0, -180, visible / 100) * 2
			end,
			Transparency = function()
				local side = props.Segment().Side
				return NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(if side == "Left" then 0.498 else 0.5, 0),
					NumberSequenceKeypoint.new(if side == "Left" then 0.499 else 0.501, 1),
					NumberSequenceKeypoint.new(1, 1),
				})
			end,
		}),
	})
end

local function PacketCircleArcs(props)
	local circle
	local actualAlpha = source(0)
	local highlighted = source(-1)
	local mouseOver = false
	local animationAlpha = derive(function()
		return TweenService:GetValue(actualAlpha(), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)
	local segments = derive(function()
		local left = {}
		local right = {}
		local ranges = {}
		local startPercent = 0
		local arcs = read(props.Arcs)

		for index, arc in arcs do
			if startPercent > 100 then
				break
			end
			local endPercent = math.min(startPercent + arc.Percent, 100)
			local zIndex = #arcs - index + 2
			ranges[index] = {
				StartPercent = startPercent,
				EndPercent = endPercent,
				Name = arc.Name,
			}

			if endPercent > 50 and startPercent <= 50 then
				table.insert(left, {
					Color = arc.Color,
					EndPercent = endPercent,
					Side = "Left",
					StartPercent = startPercent,
					VisiblePercent = 50,
					ZIndex = zIndex,
				})
			end

			local side = if endPercent > 50 then "Right" else "Left"
			table.insert(if side == "Left" then left else right, {
				Color = arc.Color,
				EndPercent = endPercent,
				Side = side,
				StartPercent = startPercent,
				VisiblePercent = endPercent,
				ZIndex = zIndex,
			})
			startPercent += arc.Percent
		end

		return { Left = left, Right = right, Ranges = ranges }
	end)

	effect(function()
		read(props.Arcs)
		actualAlpha(0)
		local elapsed = 0
		local connection
		connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed = math.min(elapsed + deltaTime * 2, 1)
			actualAlpha(elapsed)
			if elapsed == 1 then
				connection:Disconnect()
			end
		end)
		cleanup(connection)
	end)

	return create("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),

		MouseEnter = function()
			mouseOver = true
		end,
		MouseLeave = function()
			mouseOver = false
			highlighted(-1)
		end,
		MouseMoved = function(x, y)
			if not mouseOver or circle == nil then
				return
			end
			local center = circle.AbsolutePosition + circle.AbsoluteSize / 2
			local angle = math.deg(math.atan2(y - center.Y, -(x - center.X))) + 90
			if angle < 0 then
				angle += 360
			end
			highlighted(angle / 360 * 100)
		end,
		InputEnded = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local percent = highlighted()
			if percent < 0 then
				return
			end
			for _, range in segments().Ranges do
				if percent >= range.StartPercent and percent < range.EndPercent then
					if props.OnArcClicked then
						props.OnArcClicked(range.Name)
					end
					break
				end
			end
			highlighted(-1)
		end,
		action(function(instance)
			circle = instance
		end),

		create("Frame")({
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(0.5, 1),

			indexes(function()
				return segments().Left
			end, function(segment)
				return CircleArc({
					AnimationAlpha = animationAlpha,
					Highlighted = highlighted,
					Segment = segment,
				})
			end),
		}),
		create("Frame")({
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.5, 1),

			indexes(function()
				return segments().Right
			end, function(segment)
				return CircleArc({
					AnimationAlpha = animationAlpha,
					Highlighted = highlighted,
					Segment = segment,
				})
			end),
		}),
	})
end

return PacketCircleArcs
