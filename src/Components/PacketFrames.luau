local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PacketProfiler = script.Parent.Parent
local Components = PacketProfiler.Components
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)
local PacketSizeCounter = require(Packages.Directory.PacketSizeCounter)

local StudioTheme = require(Components.StudioTheme)
local CircularBuffer = require(Modules.CircularBuffer)
local PacketFrame = require(Components.PacketFrame)

local MAX_FRAMES = 256
local TOOLTIP_WIDTH = 200
-- https://developer.roblox.com/en-us/api-reference/property/Mouse/Icon#:~:text=The%20default%20mouse%20image%20is,up%2017x24%20pixels%20of%20space.
local TOOLTIP_HEIGHT_OFFSET = 24
local REMOTE_FUNCTION_EVENT_NAME = "RemoteFunctionEvent.profiler"
local GuiInset = GuiService:GetGuiInset()

local PacketFrames = Roact.Component:extend("PacketFrames")

local IsEditMode = not RunService:IsRunning()
local RemoteContext = RunService:IsClient() and "OnClientEvent" or "OnServerEvent"

local RemoteFunctionEvent = ReplicatedStorage:FindFirstChild(REMOTE_FUNCTION_EVENT_NAME, true)

function PacketFrames:init()
	self.Cleanup = {}

	self.ProfilerBackgroundRef = Roact.createRef()
	self.Enabled = not IsEditMode

	self.PacketFrames = CircularBuffer.new(MAX_FRAMES)
	self:setState({
		PacketFrames = PacketFrames,
	})
	self.PacketsChanged, self.SetPacketsChanged = Roact.createBinding(self.PacketFrames)

	function self.RemoteCallback(Remote, FirstArgument, ...)
		if not self.Enabled then
			return
		end

		local PacketSize = 0
		if RunService:IsClient() then
			PacketSize = PacketSizeCounter.GetPacketSize({
				RunContext = "Client",
				RemoteType = Remote.ClassName,
				PacketData = {FirstArgument, ...}
			})
		else
			PacketSize = PacketSizeCounter.GetPacketSize({
				RunContext = "Server",
				RemoteType = Remote.ClassName,
				PacketData = {...}
			})
		end

		self.CurrentFrame.TotalSize += PacketSize
		table.insert(self.CurrentFrame.Packets, {
			Remote = Remote,
			Data = RunService:IsClient() and {FirstArgument, ...} or {...},
			RawData = {FirstArgument, ...},
			Size = PacketSize,
			RunContext = RunService:IsClient() and "Client" or "Server",
		})
	end

	function self.InputBegan(_, Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			local FrameData = self.UpdateMouseData(Input.Position.X, Input.Position.Y + GuiInset.Y, true)
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

	self.TooltipSize, self.SetTooltipSize = Roact.createBinding(Vector2.zero)
end

function PacketFrames:didMount()
	if not IsEditMode then
		table.insert(self.Cleanup, self.props.OnPacketProfilerPaused:Connect(function(Paused: boolean)
			self.Enabled = not Paused
		end))

		self.CurrentFrame = {
			Time = os.clock(),
			TotalSize = 0,
			Packets = {},
		}

		task.spawn(function()
			-- All places that you would "expect" remotes to appear.
			-- had to add this because game:GetDescendants()
			local TargetContainers = {
				game:GetService("ReplicatedStorage"),
				game:GetService("ReplicatedFirst"),
				game:GetService("StarterPlayer"),
				game:GetService("Workspace"),
				game:GetService("StarterGui"),
				game:GetService("Players"),
				if RunService:IsServer() then game:GetService("ServerScriptService") else nil,
				if RunService:IsServer() then game:GetService("ServerStorage") else nil,
			}
			for _, Container in TargetContainers do
				for _, Object in Container:GetDescendants() do
					if Object:IsA("RemoteEvent") or Object:IsA("UnreliableRemoteEvent") then
						table.insert(self.Cleanup, Object[RemoteContext]:Connect(function(...)
							self.RemoteCallback(Object, ...)
						end))
					end
				end

				table.insert(self.Cleanup, Container.DescendantAdded:Connect(function(Object)
					if Object:IsA("RemoteEvent") or Object:IsA("UnreliableRemoteEvent") then
						table.insert(self.Cleanup, Object[RemoteContext]:Connect(function(...)
							self.RemoteCallback(Object, ...)
						end))
					end
				end))
			end

			if RemoteFunctionEvent == nil then
				local Connection; Connection = ReplicatedStorage.DescendantAdded:Connect(function(Object)
					if Object:IsA("BindableEvent") and Object.Name == REMOTE_FUNCTION_EVENT_NAME then
						RemoteFunctionEvent = Object
						table.insert(self.Cleanup, RemoteFunctionEvent.Event:Connect(self.RemoteCallback))
						Connection:Disconnect()
					end
				end)
			else
				table.insert(self.Cleanup, RemoteFunctionEvent.Event:Connect(self.RemoteCallback))
			end

			table.insert(self.Cleanup, RunService.RenderStepped:Connect(function()
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
			end))
		end)
	end
end
function PacketFrames:willUnmount()
	for _, Connection in self.Cleanup do
		Connection:Disconnect()
	end
end

function PacketFrames:render()
	local Frames = {}
	for Index = 1, MAX_FRAMES do
		Frames[Index] = Roact.createElement(PacketFrame, {
			Index = Index,
			PacketsChanged = self.PacketsChanged,
			MaxFrameSize = self.props.MaxFrameSize,
			MaxFrames = MAX_FRAMES,
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
		FrameTooltip = StudioTheme(function(Theme)
			return Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme:GetColor("Dropdown"),
				BorderColor3 = Theme:GetColor("Border"),
				Position = self.MousePosition:map(function(MousePosition)
					local Camera = workspace.CurrentCamera
					local ViewportSize = Camera and Camera.ViewportSize or Vector2.new(0, 0)
					local TooltipSize = self.TooltipSize:getValue()

					return UDim2.fromOffset(
						math.min(MousePosition.X, ViewportSize.X - TooltipSize.X),
						MousePosition.Y + (TOOLTIP_HEIGHT_OFFSET / 2)
					)
				end),
				Visible = self.MouseOver,
				ZIndex = 2,
				[Roact.Change.AbsoluteSize] = function(Rbx)
					self.SetTooltipSize(Rbx.AbsoluteSize)
				end,
				[Roact.Ref] = function(Rbx)
					if Rbx then
						self.SetTooltipSize(Rbx.AbsoluteSize)
					end
				end,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {}),
				FrameLabel = Roact.createElement("TextLabel", {
					AutoLocalize = false,
					Text = self.MouseFrameData:map(function(FrameData)
						return string.format("%d packets, %d bytes", #FrameData.Packets, FrameData.TotalSize)
					end),
					TextColor3 = Theme:GetColor("BrightText"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Font = Enum.Font.SourceSans,
					TextSize = 16,
					Size = UDim2.fromOffset(TOOLTIP_WIDTH, 16),
					BackgroundTransparency = 1,
				}),
				KBSent = Roact.createElement("TextLabel", {
					AutoLocalize = false,
					Text = self.MouseFrameData:map(function(FrameData)
						return string.format("%.3f KB sent", FrameData.TotalSize / 1000)
					end),
					TextColor3 = Theme:GetColor("BrightText"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Font = Enum.Font.SourceSans,
					TextSize = 16,
					Size = UDim2.fromOffset(TOOLTIP_WIDTH, 16),
					BackgroundTransparency = 1,
				}),
			})
		end),
		EditModeNotifier = StudioTheme(function(Theme)
			return Roact.createElement("TextLabel", {
				AutoLocalize = false,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "Start session to begin",
				TextColor3 = Theme:GetColor("WarningText"),
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