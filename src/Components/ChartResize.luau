local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local EDGE_SIZE = 8
local DIRECTION_ICONS = {
	SizeWE = "rbxassetid://18699453492",
	SizeNS = "rbxassetid://18700045701",
	SizeAll = "rbxassetid://18700129047",
}

local function ChartResize()
	local size = Vide.source(UDim2.fromOffset(650, 290))
	local target
	local direction
	local resizing = false
	local previousIcon = UserInputService.MouseIcon
	local startSize
	local startMousePosition

	local function isVisible()
		local current = target
		if current == nil then
			return false
		end
		while current do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			elseif current:IsA("LayerCollector") and not current.Enabled then
				return false
			end
			current = current.Parent
		end
		return true
	end

	local function setDirection(nextDirection)
		if resizing or direction == nextDirection then
			return
		end
		if direction == nil then
			previousIcon = UserInputService.MouseIcon
		end
		direction = nextDirection
		UserInputService.MouseIcon = DIRECTION_ICONS[nextDirection]
	end

	local function clearDirection()
		if resizing or direction == nil then
			return
		end
		direction = nil
		UserInputService.MouseIcon = previousIcon
	end

	local function stopResizing()
		if not resizing then
			return
		end
		resizing = false
		direction = nil
		UserInputService.MouseIcon = previousIcon
	end

	if not Packages.IsPlugin then
		Vide.cleanup(RunService.RenderStepped:Connect(function()
			if not isVisible() then
				stopResizing()
				clearDirection()
				return
			end

			local mouse = UserInputService:GetMouseLocation()
			if resizing then
				local delta = mouse - startMousePosition
				if direction == "SizeNS" then
					delta *= Vector2.new(0, 1)
				elseif direction == "SizeWE" then
					delta *= Vector2.new(1, 0)
				end
				size(
					UDim2.fromOffset(
						math.max(startSize.X.Offset - delta.X, 300),
						math.max(startSize.Y.Offset + delta.Y, 100)
					)
				)
				return
			end

			local position = target.AbsolutePosition + GuiService:GetGuiInset()
			local targetSize = target.AbsoluteSize
			local bottom = position.Y + targetSize.Y + EDGE_SIZE
			local right = position.X + targetSize.X
			if mouse.X < position.X - EDGE_SIZE or mouse.X > right or mouse.Y < position.Y or mouse.Y > bottom then
				clearDirection()
				return
			end

			local bottomEdge = mouse.Y > bottom - EDGE_SIZE and mouse.Y < bottom + EDGE_SIZE
			local leftEdge = mouse.X < position.X + EDGE_SIZE and mouse.X > position.X - EDGE_SIZE
			if bottomEdge or leftEdge then
				setDirection(if bottomEdge then if leftEdge then "SizeAll" else "SizeNS" else "SizeWE")
			else
				clearDirection()
			end
		end))

		Vide.cleanup(UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and direction and isVisible() then
				resizing = true
				startSize = size()
				startMousePosition = UserInputService:GetMouseLocation()
			end
		end))
		Vide.cleanup(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				stopResizing()
			end
		end))
		Vide.cleanup(function()
			UserInputService.MouseIcon = previousIcon
		end)
	end

	return {
		Size = size,
		SetTarget = function(instance)
			target = instance
		end,
	}
end

return ChartResize
