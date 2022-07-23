local Plugin = script:FindFirstAncestorOfClass("Plugin")
local Packages = Plugin.PacketAnalyzer.Packages

local Roact = require(Packages.Roact)

local PacketCircleArcs = Roact.Component:extend("PacketCircleArcs")

local function CircleArc(props)
	local Angle = -3.6*props.Data.Percent + (props.Side == "Left" and 180 or 3*180)

	return Roact.createElement("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://3587367081",
		ImageColor3 = props.Data.Color,
		Size = UDim2.fromScale(2, 1),
		Position = UDim2.fromScale(props.Side == "Left" and 0 or -1, 0),
		ZIndex = props.ZIndex,
	}, {
		UIGradient = Roact.createElement("UIGradient", {
			Color = ColorSequence.new(props.Data.Color),
			Rotation = Angle,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(props.Side == "Left" and 0.498 or 0.5, 0),
				NumberSequenceKeypoint.new(props.Side == "Left" and 0.499 or 0.501, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			-- There's a weird bug with UIGradient which causes discoloration,
			-- but this small offset fixes it
			Offset = Vector2.new(0, 0.0002),
		}),
	})
end

function PacketCircleArcs:render()
	local CircleArcs = {
		Left = {},
		Right = {},
	}
	local StartPercent = 0

	local NumArcs = #self.props.Arcs
	for Index, Arc in ipairs(self.props.Arcs) do
		local ZIndex = (NumArcs - Index) + 2
		local EndPercent = math.min(StartPercent + Arc.Percent, 100)

		if StartPercent > 100 then
			break
		end

		if EndPercent > 50 and StartPercent <= 50 then
			CircleArcs.Left[Index] = CircleArc({
				ZIndex = ZIndex,
				Data = {
					Percent = 50,
					Color = Arc.Color,
				},
				Side = "Left",
			})
		end

		local ArcSide = EndPercent > 50 and "Right" or "Left"
		CircleArcs[ArcSide][Index] = CircleArc({
			ZIndex = ZIndex,
			Data = {
				Percent = EndPercent,
				Color = Arc.Color,
			},
			Side = ArcSide,
		})

		StartPercent += Arc.Percent
	end

	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Left = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(0.5, 1),
		}, {
			Arcs = Roact.createFragment(CircleArcs.Left),
		}),
		Right = Roact.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.5, 1),
		}, {
			Arcs = Roact.createFragment(CircleArcs.Right),
		})
	})
end

return PacketCircleArcs