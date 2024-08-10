local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local PacketProfiler = script.Parent.Parent
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)

local ChartResize = Roact.Component:extend("ChartResize")

function ChartResize:init()
	self.Size, self.SetSize = Roact.createBinding(UDim2.fromOffset(650, 290))
	if not Packages.IsPlugin then
		self.Connections = {}
		local PreviousIcon = UserInputService.MouseIcon

		local UpdateConnection

		local IconResizing = false
		local IsResizing = false

		local DirectionIcons = {
			SizeWE = "rbxassetid://18699453492",
			SizeNS = "rbxassetid://18700045701",
			SizeAll = "rbxassetid://18700129047",
		}
		function self.AddIcon(Direction)
			if IsResizing or IconResizing == Direction then
				return
			end

			if IconResizing == false then
				PreviousIcon = UserInputService.MouseIcon
			end
			IconResizing = Direction
			UserInputService.MouseIcon = DirectionIcons[Direction]
		end
		function self.RemoveIcon()
			if IsResizing or not IconResizing then
				return
			end

			IconResizing = false
			UserInputService.MouseIcon = PreviousIcon
		end

		local EdgeSize = 8
		function self.SetSizeTarget(Rbx)
			if not Rbx then
				return
			end

			for _, Connection in self.Connections do
				Connection:Disconnect()
			end
			table.clear(self.Connections)

			table.insert(self.Connections, RunService.RenderStepped:Connect(function()
				local GUI_INSET = GuiService:GetGuiInset()

				local Mouse = UserInputService:GetMouseLocation()
				local Position = Rbx.AbsolutePosition + GUI_INSET
				local Size = Rbx.AbsoluteSize

				local BottomPosition = Position.Y + Size.Y + EdgeSize
				local RightmostPosition = Position.X + Size.X
				local MouseOutside = Mouse.X < Position.X - EdgeSize or Mouse.X > RightmostPosition or Mouse.Y < Position.Y or Mouse.Y > BottomPosition
				if MouseOutside then
					self.RemoveIcon()
					return
				end

				-- check if the mouse is at the edges of the frame
				local BottomEdge = Mouse.Y > BottomPosition - EdgeSize and Mouse.Y < BottomPosition + EdgeSize
				local LeftEdge = Mouse.X < Position.X + EdgeSize and Mouse.X > Position.X - EdgeSize

				if BottomEdge or LeftEdge then
					local Direction = if BottomEdge then if LeftEdge then "SizeAll" else "SizeNS" else "SizeWE"
					self.AddIcon(Direction)
				else
					self.RemoveIcon()
				end
			end))

			table.insert(self.Connections, UserInputService.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 and IconResizing then
					self.StartResizing()
				end
			end))
			table.insert(self.Connections, UserInputService.InputEnded:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 then
					self.StopResizing()
				end
			end))
		end

		function self.StartResizing()
			if IsResizing then
				return
			end

			IsResizing = true

			local StartPosition = self.Size:getValue()
			local Mouse = UserInputService:GetMouseLocation()
			local StartMousePosition = Vector2.new(Mouse.X, Mouse.Y)

			UpdateConnection = RunService.RenderStepped:Connect(function()
				local Delta = UserInputService:GetMouseLocation() - StartMousePosition
				if IconResizing == "SizeNS" then
				Delta *= Vector2.new(0, 1)
				elseif IconResizing == "SizeWE" then
					Delta *= Vector2.new(1, 0)
				end

				local NewSize = UDim2.fromOffset(
					math.max(StartPosition.X.Offset - Delta.X, 300),
					math.max(StartPosition.Y.Offset + Delta.Y, 100)
				)
				self.SetSize(NewSize)
			end)
		end

		function self.StopResizing()
			if not IsResizing then
				return
			end

			IsResizing = false
			self.RemoveIcon()

			UpdateConnection:Disconnect()
			UpdateConnection = nil
		end
	end
end

function ChartResize:render()
	local PacketChart = Roact.oneChild(self.props[Roact.Children])
	return PacketChart({
		UISize = self.Size,
		StartResizing = self.StartResizing,
		StopResizing = self.StopResizing,
		AddIcon = self.AddIcon,
		RemoveIcon = self.RemoveIcon,
		SetSizeTarget = self.SetSizeTarget,
	})
end

function ChartResize:willUnmount()
	if self.StopResizing then
		self.StopResizing()
	end

	if self.Connections then
		for _, Connection in self.Connections do
			Connection:Disconnect()
		end

		table.clear(self.Connections)
	end
end

local function ChartResizeInit(PacketChart)
	return Roact.createElement(ChartResize, {}, {
		PacketChart = PacketChart,
	})
end

return ChartResizeInit