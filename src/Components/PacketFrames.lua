local RunService = game:GetService("RunService")

local Plugin = script:FindFirstAncestorOfClass("Plugin")
local Packages = Plugin.PacketProfiler.Packages
local Components = Plugin.PacketProfiler.Components
local Modules = Plugin.PacketProfiler.Modules

local Roact = require(Packages.Roact)
local StudioTheme = require(Components.StudioTheme)
local CircularBuffer = require(Modules.CircularBuffer)
local CountPacketSize = require(Modules.PacketSizeCounter)

local MAX_FRAMES = 256
local TOOLTIP_WIDTH = 200
-- https://developer.roblox.com/en-us/api-reference/property/Mouse/Icon#:~:text=The%20default%20mouse%20image%20is,up%2017x24%20pixels%20of%20space.
local TOOLTIP_HEIGHT_OFFSET = 24

local PacketFrames = Roact.Component:extend("PacketFrames")
local PacketFrame = Roact.Component:extend("PacketFrame")

local IsEditMode = RunService:IsEdit()
local RemoteContext = RunService:IsClient() and "OnClientEvent" or "OnServerEvent"

function PacketFrame:render()
	local props = self.props
	return Roact.createElement("Frame", {
		Size = props.PacketsChanged:map(function(Packets)
			local FrameData = Packets[props.Index]
			if not FrameData then
				return Roact.Constant.SkipBindingUpdate
			end

			local FrameScale = math.min(FrameData.TotalSize / self.props.MaxFrameSize, 1)
			local FrameSize = UDim2.fromScale(1 / MAX_FRAMES, FrameScale)
			if FrameSize == self.PreviousFrameSize then
				return Roact.Constant.SkipBindingUpdate
			end

			self.PreviousFrameSize = FrameSize
			return FrameSize
		end),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(1 - (props.Index / MAX_FRAMES), 1),
		BorderSizePixel = 0,
		BackgroundColor3 = props.PacketsChanged:map(function(Packets)
			local FrameData = Packets[props.Index]
			if not FrameData then
				return Roact.Constant.SkipBindingUpdate
			end

			local FrameScale = math.min(FrameData.TotalSize / self.props.MaxFrameSize, 1)
			local FrameColor =Color3.fromHex("#93ff1f"):Lerp(Color3.fromHex("#ed1c1c"), FrameScale)
			if FrameColor == self.PreviousFrameColor then
				return Roact.Constant.SkipBindingUpdate
			end

			self.PreviousFrameColor = FrameColor
			return FrameColor
		end),
		Visible = props.PacketsChanged:map(function(Packets)
			local IsVisible = Packets[props.Index] ~= nil
			if IsVisible == self.PreviousIsVisible then
				return Roact.Constant.SkipBindingUpdate
			end

			self.PreviousIsVisible = IsVisible
			return IsVisible
		end),
		BorderColor3 = Color3.new(1, 1, 1),
	})
end

function PacketFrames:init()
	self.ProfilerBackgroundRef = Roact.createRef()
	self.Enabled = not IsEditMode

	self.PacketFrames = CircularBuffer.new(MAX_FRAMES)
	self:setState({
		PacketFrames = PacketFrames,
	})
	self.PacketsChanged, self.SetPacketsChanged = Roact.createBinding(self.PacketFrames)

	function self.RemoteCallback(Remote, ...)
		if not self.Enabled then
			return
		end

		local PacketSize = CountPacketSize(...)
		self.CurrentFrame.TotalSize += PacketSize
		table.insert(self.CurrentFrame.Packets, {
			Remote = Remote,
			FirstArgument = (...),
			Size = PacketSize,
		})
	end

	function self.InputBegan(_, Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			local FrameData = self.UpdateMouseData(Input.Position.X, Input.Position.Y, true)
			if FrameData then
				self.props.Signals.ProfilerFrameSelected:Fire(FrameData)
			end
			self.props.OnPacketProfilerPaused:Fire(true)
		end
	end

	self.MousePosition, self.SetMousePosition = Roact.createBinding(Vector2.new(0, 0))
	self.MouseOver, self.SetMouseOver = Roact.createBinding(false)

	local DefaultFrameData = {
		Selected = false,
		Index = 0,
		TotalSize = 0,
		Packets = {},
	}

	self.SelectedFrameData, self.SetSelectedFrameData = Roact.createBinding(DefaultFrameData)
	self.MouseFrameData, self.SetMouseFrameData = Roact.createBinding(DefaultFrameData)

	function self.UpdateMouseData(MouseX: number, MouseY: number, Selected: boolean)
		self.SetMousePosition(Vector2.new(MouseX, MouseY))

		local ProfilerBackground: Frame = self.ProfilerBackgroundRef:getValue()
		local ProfilerFrameSize = ProfilerBackground.AbsoluteSize

		local FrameSize = ProfilerFrameSize.X * (1 / MAX_FRAMES)
		local HoveringIndex = MAX_FRAMES - math.floor(MouseX / FrameSize)

		local FrameData = MouseX > 0 and self.PacketFrames[HoveringIndex] or nil

		if FrameData then
			local MouseFrameData = {
				Selected = Selected,
				Index = HoveringIndex,
				TotalSize = FrameData.TotalSize,
				Packets = FrameData.Packets,
			}

			if Selected then
				self.SetSelectedFrameData(MouseFrameData)
			end
			self.SetMouseFrameData(MouseFrameData)
		else
			self.SetMouseFrameData(DefaultFrameData)
		end

		return FrameData
	end

	function self.MouseEnter(_, MouseX: number, MouseY: number)
		if IsEditMode then
			return
		end

		self.UpdateMouseData(MouseX, MouseY, false)
		self.SetMouseOver(true)
	end
	function self.MouseMoved(_, MouseX: number, MouseY: number)
		if IsEditMode then
			return
		end

		self.UpdateMouseData(MouseX, MouseY, false)
	end
	function self.MouseLeave(_)
		if IsEditMode then
			return
		end

		self.UpdateMouseData(-1, -1, false)
		self.SetMouseOver(false)
	end
end

function PacketFrames:didMount()
	if not IsEditMode then
		self.props.OnPacketProfilerPaused:Connect(function(Paused: boolean)
			self.Enabled = not Paused
		end)

		self.CurrentFrame = {
			Time = os.clock(),
			TotalSize = 0,
			Packets = {},
		}

		for _, Object in next, game:GetDescendants() do
			if Object:IsA("RemoteEvent") then
				Object[RemoteContext]:Connect(function(...)
					self.RemoteCallback(Object, ...)
				end)
			end
		end
		game.DescendantAdded:Connect(function(Object)
			if Object:IsA("RemoteEvent") then
				Object[RemoteContext]:Connect(function(...)
					self.RemoteCallback(Object, ...)
				end)
			end
		end)

		RunService.RenderStepped:Connect(function()
			if not self.Enabled then
				return
			end

			self.PacketFrames:push(self.CurrentFrame)
			self.SetPacketsChanged(self.PacketFrames)

			self.CurrentFrame = {
				Time = os.clock(),
				TotalSize = 0,
				Packets = {},
			}

			if self.MouseOver:getValue() then
				local MousePosition = self.MousePosition:getValue()
				self.UpdateMouseData(MousePosition.X, MousePosition.Y, self.SelectedFrameData:getValue().Selected)
			end
		end)
	end
end

function PacketFrames:render()
	local Frames = {}
	for Index = 1, MAX_FRAMES do
		Frames[Index] = Roact.createElement(PacketFrame, {
			Index = Index,
			PacketsChanged = self.PacketsChanged,
			MaxFrameSize = self.props.MaxFrameSize,
		})
	end

	return Roact.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		[Roact.Event.InputBegan] = self.InputBegan,

		[Roact.Event.MouseEnter] = self.MouseEnter,
		[Roact.Event.MouseMoved] = self.MouseMoved,
		[Roact.Event.MouseLeave] = self.MouseLeave,

		[Roact.Ref] = self.ProfilerBackgroundRef,
	}, {
		Frames = Roact.createFragment(Frames),
		SelectedHighlight = Roact.createElement("Frame", {
			Size = UDim2.fromScale(1 / MAX_FRAMES, 1),
			BackgroundTransparency = 0.5,
			Position = self.SelectedFrameData:map(function(FrameData)
				return UDim2.fromScale(1 - (FrameData.Index / MAX_FRAMES), 0)
			end),
			BorderSizePixel = 0,
			Visible = self.SelectedFrameData:map(function(FrameData)
				return FrameData and FrameData.Selected
			end),
			ZIndex = 2,
			BackgroundColor3 = Color3.fromHex("#34ff30"),
		}),
		FrameHighlight = Roact.createElement("Frame", {
			Size = self.MouseFrameData:map(function(FrameData)
				local FrameScale = math.min(FrameData.TotalSize / self.props.MaxFrameSize, 1)
				return UDim2.fromScale(1 / MAX_FRAMES, FrameScale)
			end),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 0.25,
			Position = self.MouseFrameData:map(function(FrameData)
				return UDim2.fromScale(1 - (FrameData.Index / MAX_FRAMES), 1)
			end),
			ZIndex = 2,
			BorderSizePixel = 0,
			Visible = self.MouseFrameData:map(function(FrameData)
				return FrameData.Index ~= 0
			end),
			BackgroundColor3 = Color3.fromHex("#e8e8e8"),
		}),
		FrameTooltip = StudioTheme(function(Theme: StudioTheme)
			return Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Dropdown),
				BorderColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.Border),
				Position = self.MousePosition:map(function(MousePosition)
					return UDim2.fromOffset(MousePosition.X, MousePosition.Y + TOOLTIP_HEIGHT_OFFSET)
				end),
				Visible = self.MouseOver,
				ZIndex = 2,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {}),
				FrameLabel = Roact.createElement("TextLabel", {
					Text = self.MouseFrameData:map(function(FrameData)
						return string.format("%d packets, %d bytes", #FrameData.Packets, FrameData.TotalSize)
					end),
					TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.BrightText),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Font = Enum.Font.SourceSans,
					TextSize = 16,
					Size = UDim2.fromOffset(TOOLTIP_WIDTH, 16),
					BackgroundTransparency = 1,
				}),
				KBSent = Roact.createElement("TextLabel", {
					Text = self.MouseFrameData:map(function(FrameData)
						return string.format("%.2f KB sent", FrameData.TotalSize / 1000)
					end),
					TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.BrightText),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Font = Enum.Font.SourceSans,
					TextSize = 16,
					Size = UDim2.fromOffset(TOOLTIP_WIDTH, 16),
					BackgroundTransparency = 1,
				}),
			})
		end),
		EditModeNotifier = StudioTheme(function(Theme: StudioTheme)
			return Roact.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "Start session to begin",
				TextColor3 = Theme:GetColor(Enum.StudioStyleGuideColor.WarningText),
				TextSize = 20,
				Font = Enum.Font.SourceSans,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Visible = IsEditMode,
			})
		end),
	})
end

return PacketFrames