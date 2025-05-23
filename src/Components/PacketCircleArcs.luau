local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local PacketProfiler = script.Parent.Parent
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)

local PacketCircleArcs = Roact.Component:extend("PacketCircleArcs")

local function lerp(a, b, alpha)
	return a + (b - a)*alpha
end

local function CircleArc(props)
	local EndPercent = props.Data.EndPercent
	local StartPercent = props.Data.StartPercent
	local VisiblePercent = props.Data.VisiblePercent

	return Roact.createElement("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://3587367081",
		ImageColor3 = props.Highlighted:map(function(Percent)
			if Percent >= StartPercent and Percent < EndPercent then
				return props.Data.Color:Lerp(Color3.new(1, 1, 1), 0.5)
			end

			return props.Data.Color
		end),
		Size = UDim2.fromScale(2, 1),
		Position = UDim2.fromScale(props.Side == "Left" and 0 or -1, 0),
		ZIndex = props.ZIndex,
	}, {
		UIGradient = Roact.createElement("UIGradient", {
			Rotation = props.AnimationAlpha:map(function(Alpha)
				if props.Side == "Left" then
					local AlphaPercent = lerp(0, VisiblePercent, math.clamp(Alpha*2, 0, 1))
					local Angle = -3.6*AlphaPercent + 180
					return Angle
				else
					local AlphaPercent = lerp(0, VisiblePercent - 50, math.clamp(Alpha*2 - 1, 0, 1))
					return lerp(0, -180, AlphaPercent / 100) * 2
				end
			end),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(props.Side == "Left" and 0.498 or 0.5, 0),
				NumberSequenceKeypoint.new(props.Side == "Left" and 0.499 or 0.501, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

function PacketCircleArcs:init()
	self.AnimationAlpha, self.SetAnimationAlpha = Roact.createBinding(0)
	self.ActualAlpha, self.SetActualAlpha = Roact.createBinding(0)
	self.MousePosition, self.SetMousePosition = Roact.createBinding(Vector2.zero)
	self.HighlightedPercent, self.SetHighlightedPercent = Roact.createBinding(-1)

	self.DebugMousePos, self.SetDebugMousePos = Roact.createBinding(UDim2.fromOffset(0, 0))
	self.ShowDebug, self.SetShowDebug = Roact.createBinding(false)

	local Speed = 2
	local Mouse = Packages.IsPlugin and self.props.PluginMouse or Players.LocalPlayer:GetMouse()
	RunService.RenderStepped:Connect(function(Step)
		local MousePosition = Vector2.new(Mouse.X, Mouse.Y)
		self.SetMousePosition(MousePosition)

		local alpha = self.ActualAlpha:getValue()

		self.SetAnimationAlpha(TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		self.SetActualAlpha(math.clamp(alpha + Step*Speed, 0, 1))
	end)
end

function PacketCircleArcs:render()
	local CircleArcs = {
		Left = {},
		Right = {},
	}
	local StartPercent = 0

	self.SetActualAlpha(0)

	local ArcData = {}
	local NumArcs = #self.props.Arcs
	for Index, Arc in self.props.Arcs do
		local ZIndex = (NumArcs - Index) + 2
		local EndPercent = math.min(StartPercent + Arc.Percent, 100)

		if StartPercent > 100 then
			break
		end

		ArcData[Index] = {
			StartPercent = StartPercent,
			EndPercent = EndPercent,
			Color = Arc.Color,
			Name = Arc.Name,
		}

		if EndPercent > 50 and StartPercent <= 50 then
			CircleArcs.Left[Index] = CircleArc({
				ZIndex = ZIndex,
				Data = {
					StartPercent = StartPercent,
					EndPercent = EndPercent,
					VisiblePercent = 50,
					Color = Arc.Color,
				},
				Side = "Left",
				AnimationAlpha = self.AnimationAlpha,
				Highlighted = self.HighlightedPercent,
			})
		end

		local ArcSide = EndPercent > 50 and "Right" or "Left"
		CircleArcs[ArcSide][Index] = CircleArc({
			ZIndex = ZIndex,
			Data = {
				StartPercent = StartPercent,
				EndPercent = EndPercent,
				VisiblePercent = EndPercent,
				Color = Arc.Color,
			},
			Side = ArcSide,
			AnimationAlpha = self.AnimationAlpha,
			Highlighted = self.HighlightedPercent,
		})

		StartPercent += Arc.Percent
	end

	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),

		[Roact.Event.MouseEnter] = function(Rbx, X, Y)
			self.MouseOver = true
			self.SetShowDebug(true)
		end,
		[Roact.Event.MouseLeave] = function()
			self.MouseOver = false
			self.SetHighlightedPercent(-1)
			self.SetShowDebug(false)
		end,
		[Roact.Event.MouseMoved] = function(Rbx, X, Y)
			if self.MouseOver then
				local MousePosition = Vector2.new(X, Y)
				local Center = Rbx.AbsolutePosition + Rbx.AbsoluteSize/2

				self.SetDebugMousePos(UDim2.fromOffset(X - 1, Y - 1))

				local Angle = math.deg(math.atan2(MousePosition.Y - Center.Y, -(MousePosition.X - Center.X))) + 90
				if Angle < 0 then
					Angle += 360
				end

				local Percent = (Angle / 360) * 100
				self.SetHighlightedPercent(Percent)
			end
		end,
		[Roact.Event.InputEnded] = function(_, inputObject)
			if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			
			local Percent = self.HighlightedPercent:getValue()
			if Percent == -1 then
				return
			end

			for Index, Arc in ArcData do
				if Percent >= Arc.StartPercent and Percent < Arc.EndPercent then
					if self.props.OnArcClicked then
						self.props.OnArcClicked(Arc.Name)
					end
					break
				end
			end

			self.SetHighlightedPercent(-1)
		end,
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
		}),
		--[[
		DebugFrame = Roact.createElement("Frame", {
			BackgroundColor3 = Color3.new(1, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(4, 4),
			Position = self.DebugMousePos,
			Visible = self.ShowDebug,
			ZIndex = 1000,
		})
		]]
	})
end

return PacketCircleArcs