local Color3 = import("../types/Color3")
local GuiButton = import("./GuiButton")
local InstanceProperty = import("../InstanceProperty")
local Rect = import("../types/Rect")
local ScaleType = import("../Enum/ScaleType")

local ImageButton = GuiButton:extend("ImageButton", {
	creatable = true,
})

ImageButton.properties.Image = InstanceProperty.typed("string", {
	getDefault = function()
		return ""
	end,
})

ImageButton.properties.ImageColor3 = InstanceProperty.typed("Color3", {
	getDefault = function()
		return Color3.new()
	end,
})

ImageButton.properties.ScaleType = InstanceProperty.enum(ScaleType, {
	getDefault = function()
		return ScaleType.Stretch
	end,
})

ImageButton.properties.SliceCenter = InstanceProperty.typed("Rect", {
	getDefault = function()
		return Rect.new(0, 0, 1, 1)
	end,
})

return ImageButton