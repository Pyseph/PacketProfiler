local PacketProfiler = script.Parent.Parent
local Modules = PacketProfiler.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)

local PacketFrame = Roact.Component:extend("PacketFrame")

function PacketFrame:render()
	local props = self.props
	return Roact.createElement("ImageLabel", {
		Size = props.PacketsChanged:map(function(Packets)
			local FrameData = Packets[props.Index]
			if not FrameData then
				return Roact.Constant.SkipBindingUpdate
			end

			local FrameScale = math.min(FrameData.TotalSize / self.props.MaxFrameSize, 1)
			local FrameSize = UDim2.fromScale(1 / props.MaxFrames, FrameScale)
			if FrameSize == self.PreviousFrameSize then
				return Roact.Constant.SkipBindingUpdate
			end

			self.PreviousFrameSize = FrameSize
			return FrameSize
		end),
		Image = "rbxassetid://10370998310",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(1 - (props.Index / props.MaxFrames), 1),
		BorderSizePixel = 0,
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

return PacketFrame