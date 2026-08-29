local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local action = Vide.action
local create = Vide.create

local TimelineRenderer = {}
TimelineRenderer.__index = TimelineRenderer

local function setBarColor(bar, color)
	bar.BackgroundColor3 = color
	local gradient = bar:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color)
	end
end

function TimelineRenderer.new(maxFrames, requestRender)
	return setmetatable({
		MaxFrames = maxFrames,
		Cursor = 0,
		Strip = nil,
		Bars = table.create(maxFrames * 2),
		Frames = table.create(maxFrames),
		MountedBars = 0,
		Initialized = false,
		Color = nil,
		RequestRender = requestRender,
	}, TimelineRenderer)
end

function TimelineRenderer:IsReady()
	return self.Strip ~= nil and self.MountedBars == self.MaxFrames * 2
end

function TimelineRenderer:_didMount()
	if self:IsReady() then
		self.RequestRender()
	end
end

function TimelineRenderer:Create()
	local bars = table.create(self.MaxFrames * 2)
	local stripLength = self.MaxFrames * 2

	for index = 1, stripLength do
		bars[index] = create("Frame")({
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromScale((index - 1) / stripLength, 1),
			Size = UDim2.fromScale(1 / stripLength, 0),
			Visible = false,

			action(function(bar)
				if self.Bars[index] == nil then
					self.MountedBars += 1
				end
				self.Bars[index] = bar
				self:_didMount()
			end),

			create("UIGradient")({
				Rotation = 90,
			}),
		})
	end

	return create("Frame")({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),

		create("Frame")({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(2, 1),

			action(function(strip)
				self.Strip = strip
				self:_didMount()
			end),

			bars,
		}),
	})
end

function TimelineRenderer:_setColor(color)
	if self.Color == color then
		return
	end
	self.Color = color
	for _, bar in self.Bars do
		setBarColor(bar, color)
	end
end

function TimelineRenderer:_renderSlot(profiler, slot, view, maxFrameSize)
	local frame = self.Frames[slot]
	local totalSize = if frame then profiler:GetFrameSize(frame, view) else 0
	local height = math.clamp(totalSize / math.max(maxFrameSize, 1), 0, 1)

	for _, barIndex in { slot, slot + self.MaxFrames } do
		local bar = self.Bars[barIndex]
		bar.Size = UDim2.fromScale(1 / (self.MaxFrames * 2), height)
		bar.Visible = height > 0
	end
end

function TimelineRenderer:_positionStrip()
	self.Strip.Position = UDim2.fromScale(-self.Cursor / self.MaxFrames, 0)
end

function TimelineRenderer:Refresh(profiler, view, maxFrameSize, color)
	if not self:IsReady() then
		return
	end

	self:_setColor(color)
	for slot = 1, self.MaxFrames do
		self:_renderSlot(profiler, slot, view, maxFrameSize)
	end
	self:_positionStrip()
end

function TimelineRenderer:Initialize(profiler, view, maxFrameSize, color)
	if not self:IsReady() then
		return
	end

	table.clear(self.Frames)
	self.Cursor = 0
	local frameCount = math.min(#profiler.Frames, self.MaxFrames)
	for age = frameCount, 1, -1 do
		self.Cursor = self.Cursor % self.MaxFrames + 1
		self.Frames[self.Cursor] = profiler.Frames[age]
	end
	self.Initialized = true
	self:Refresh(profiler, view, maxFrameSize, color)
end

function TimelineRenderer:Render(profiler, view, maxFrameSize, color)
	if self.Initialized then
		self:Refresh(profiler, view, maxFrameSize, color)
	else
		self:Initialize(profiler, view, maxFrameSize, color)
	end
end

function TimelineRenderer:CommitBatch(profiler, frames, view, maxFrameSize, color)
	if not self:IsReady() then
		return
	end
	if not self.Initialized then
		self:Initialize(profiler, view, maxFrameSize, color)
		return
	end

	self:_setColor(color)
	for _, frame in frames do
		self.Cursor = self.Cursor % self.MaxFrames + 1
		self.Frames[self.Cursor] = frame
		self:_renderSlot(profiler, self.Cursor, view, maxFrameSize)
	end
	self:_positionStrip()
end

function TimelineRenderer:Commit(profiler, frame, view, maxFrameSize, color)
	self:CommitBatch(profiler, { frame }, view, maxFrameSize, color)
end

function TimelineRenderer:GetFrame(age)
	if not self.Initialized or age < 1 or age > self.MaxFrames then
		return nil
	end
	local slot = (self.Cursor - age) % self.MaxFrames + 1
	return self.Frames[slot]
end

return TimelineRenderer
