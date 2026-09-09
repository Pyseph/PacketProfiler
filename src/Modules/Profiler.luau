local RunService = game:GetService("RunService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)

local Signal = require(Packages.Directory.Signal)
local Cleanup = require(PacketProfiler.Modules.Cleanup)
local FrameStore = require(PacketProfiler.Modules.FrameStore)
local HookRegistry = require(PacketProfiler.Modules.HookRegistry)
local LayerRegistry = require(PacketProfiler.Modules.LayerRegistry)
local TopFrameStore = require(PacketProfiler.Modules.TopFrameStore)

local MAX_FRAMES = 256
local MAX_TOP_FRAMES = 50
local FRAME_INTERVAL = 1 / 60

local Profiler = {}
Profiler.__index = Profiler

local function copyPacket(packet, layer)
	return {
		LayerId = layer.Id,
		IncludeInAll = layer.IncludeInAll ~= false,
		Name = packet.Name,
		Size = packet.Size,
		Data = packet.Data,
		RawData = packet.RawData,
		Metadata = packet.Metadata,
		Timestamp = packet.Timestamp or os.clock(),
	}
end

local function validatePacket(packet)
	assert(type(packet) == "table", "Packet must be a table")
	assert(type(packet.Name) == "string", "Packet.Name must be a string")
	assert(type(packet.Size) == "number" and packet.Size >= 0, "Packet.Size must be a non-negative number")
end

function Profiler.new()
	local frameStore = FrameStore.new(MAX_FRAMES, FRAME_INTERVAL)
	local self = setmetatable({
		Frames = frameStore.Frames,
		FrameCommitted = Signal.new(),
		FrameBatchCommitted = Signal.new(),
		LayersChanged = Signal.new(),
		PauseChanged = Signal.new(),
		CaptureChanged = Signal.new(),
		ViewChanged = Signal.new(),
		SelectionChanged = Signal.new(),
		TopFramesChanged = Signal.new(),
		SelectedFrame = nil,
		View = "all",
		Paused = false,
		_running = false,
		_cleanup = {},
		_frames = frameStore,
		_topFrames = TopFrameStore.new(MAX_TOP_FRAMES),
		_hooks = HookRegistry.new(),
		_addons = {},
	}, Profiler)

	self._registry = LayerRegistry.new(function(layer)
		return {
			Layer = layer,
			Profiler = self,
			Emit = function(packet)
				return self:Record(layer.Id, packet)
			end,
		}
	end)

	table.insert(
		self._cleanup,
		self._registry.LayerAdded:Connect(function()
			self.LayersChanged:Fire(self:GetLayers())
		end)
	)
	table.insert(
		self._cleanup,
		self._registry.LayerRemoved:Connect(function(layer)
			self._topFrames:RemoveView(layer.Id)
			if self.View == layer.Id then
				self:SetView("all")
			end
			self.LayersChanged:Fire(self:GetLayers())
		end)
	)

	return self
end

function Profiler:GetMaxFrames()
	return MAX_FRAMES
end

function Profiler:GetFrameInterval()
	return FRAME_INTERVAL
end

function Profiler:GetAllViewName()
	for _, layer in self._registry:GetAll() do
		if layer.IncludeInAll == false then
			return "Combined bytes"
		end
	end
	return "All traffic"
end

function Profiler:GetLayers()
	local layers = {}
	for index, layer in self._registry:GetAll() do
		layers[index] = table.clone(layer)
		layers[index]._cleanup = nil
	end
	return layers
end

function Profiler:GetLayer(layerId)
	local layer = self._registry:Get(layerId)
	if layer == nil then
		return nil
	end

	local copy = table.clone(layer)
	copy._cleanup = nil
	return copy
end

function Profiler:RegisterLayer(layer)
	return self._registry:Register(layer)
end

function Profiler:RegisterHook(stage, callback)
	return self._hooks:Register(stage, callback)
end

function Profiler:RegisterAddon(addon)
	assert(type(addon) == "table" and type(addon.Id) == "string", "Addon.Id must be a string")
	assert(type(addon.Install) == "function", "Addon.Install must be a function")
	assert(self._addons[addon.Id] == nil, string.format("Addon %q is already registered", addon.Id))

	local installed, cleanup = pcall(addon.Install, self)
	assert(installed, string.format("Addon %q failed to install: %s", addon.Id, tostring(cleanup)))
	self._addons[addon.Id] = cleanup or false

	local connected = true
	return {
		Disconnect = function()
			if not connected then
				return
			end
			connected = false
			local addonCleanup = self._addons[addon.Id]
			if addonCleanup then
				Cleanup.run(addonCleanup)
			end
			self._addons[addon.Id] = nil
		end,
	}
end

function Profiler:Record(layerId, packet)
	if not self:IsCapturing() then
		return false
	end
	local layer = self._registry:Get(layerId)
	assert(layer, string.format("Cannot record for unknown layer %q", tostring(layerId)))
	validatePacket(packet)

	local normalized = self._hooks:Transform("BeforeRecord", copyPacket(packet, layer))
	if normalized == false then
		return false
	end
	normalized.LayerId = layerId
	normalized.IncludeInAll = layer.IncludeInAll ~= false
	validatePacket(normalized)

	local frame = self._frames:Record(normalized)
	self._hooks:Run("AfterRecord", normalized, frame)

	return true
end

function Profiler:GetFrameSize(frame, view)
	return self._frames:GetSize(frame, view)
end

function Profiler:GetFramePackets(frame, view)
	return self._frames:GetPackets(frame, view)
end

function Profiler:GetTopFrames(view, limit)
	assert(view == "all" or self._registry:Get(view), string.format("Unknown layer view %q", tostring(view)))
	limit = math.clamp(math.floor(limit or 10), 1, MAX_TOP_FRAMES)
	return self._topFrames:Get(view, limit)
end

function Profiler:GetViewFrame(frame, view)
	return self._frames:GetView(frame, view or self.View)
end

function Profiler:SetView(view)
	assert(view == "all" or self._registry:Get(view), string.format("Unknown layer view %q", tostring(view)))
	if self.View == view then
		return
	end
	self.View = view
	self.ViewChanged:Fire(view)
	if self.SelectedFrame then
		self.SelectionChanged:Fire(self:GetViewFrame(self.SelectedFrame))
	end
end

function Profiler:SetPaused(paused)
	paused = paused == true
	if self.Paused == paused then
		return
	end
	self.Paused = paused
	self:_updateCapture()
	self.PauseChanged:Fire(paused)
end

function Profiler:IsCapturing()
	return self._running and not self.Paused
end

function Profiler:SelectFrame(frame)
	self.SelectedFrame = frame
	self.SelectionChanged:Fire(frame and self:GetViewFrame(frame) or nil)
end

function Profiler:_commitFrame()
	if not self:IsCapturing() then
		return nil
	end

	local frame = self._frames:Commit()
	local topFramesChanged = frame.PacketCount > 0
		and self._topFrames:Record(frame, self._registry:GetAll(), function(targetFrame, view)
			return self._frames:GetSize(targetFrame, view)
		end)
	self._hooks:Run("FrameCommitted", frame)
	self.FrameCommitted:Fire(frame, self.Frames)
	return frame, topFramesChanged
end

function Profiler:Start()
	if self._running then
		return
	end
	self._running = true
	self:_updateCapture()
end

function Profiler:Stop()
	if not self._running then
		return
	end
	self._running = false
	self:_updateCapture()
end

function Profiler:_updateCapture()
	if self._stepConnection then
		self._stepConnection:Disconnect()
		self._stepConnection = nil
	end
	if not self:IsCapturing() then
		self._registry:Stop()
		self.CaptureChanged:Fire(false)
		return
	end
	self._frames:Seek(os.clock())
	self._registry:Start()

	local stepSignal = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat
	local elapsed = 0
	self._stepConnection = stepSignal:Connect(function(deltaTime)
		elapsed += deltaTime
		local framesDue = math.floor(elapsed / FRAME_INTERVAL)
		if framesDue > 0 then
			elapsed -= framesDue * FRAME_INTERVAL
			local skippedFrames = math.max(framesDue - MAX_FRAMES, 0)
			self._frames:Skip(skippedFrames)
			local committedFrames = table.create(framesDue - skippedFrames)
			local topFramesChanged = false
			for _ = 1, framesDue - skippedFrames do
				local frame, changed = self:_commitFrame()
				topFramesChanged = topFramesChanged or changed
				if frame then
					table.insert(committedFrames, frame)
				end
			end
			if topFramesChanged then
				self.TopFramesChanged:Fire()
			end
			if #committedFrames > 0 then
				self.FrameBatchCommitted:Fire(committedFrames, self.Frames)
			end
		end
	end)
	self.CaptureChanged:Fire(true)
end

function Profiler:Destroy()
	self:Stop()
	for _, cleanup in self._addons do
		if cleanup then
			Cleanup.run(cleanup)
		end
	end
	table.clear(self._addons)

	self._registry:Destroy()
	Cleanup.all(self._cleanup)
	self.FrameCommitted:DisconnectAll()
	self.FrameBatchCommitted:DisconnectAll()
	self.LayersChanged:DisconnectAll()
	self.PauseChanged:DisconnectAll()
	self.CaptureChanged:DisconnectAll()
	self.ViewChanged:DisconnectAll()
	self.SelectionChanged:DisconnectAll()
	self.TopFramesChanged:DisconnectAll()
	self._topFrames:Clear()
	self._hooks:Destroy()
	self._running = false
end

return Profiler
