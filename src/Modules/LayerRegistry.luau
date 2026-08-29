local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)

local Signal = require(Packages.Directory.Signal)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local LayerRegistry = {}
LayerRegistry.__index = LayerRegistry

local function isPositiveFinite(value)
	return type(value) == "number" and value > 0 and value == value and value < math.huge
end

local function validateLayer(layer)
	assert(type(layer) == "table", "Layer must be a table")
	assert(type(layer.Id) == "string" and layer.Id ~= "", "Layer.Id must be a non-empty string")
	assert(type(layer.Name) == "string" and layer.Name ~= "", "Layer.Name must be a non-empty string")
	assert(layer.Start == nil or type(layer.Start) == "function", "Layer.Start must be a function")
	assert(layer.EntryName == nil or type(layer.EntryName) == "string", "Layer.EntryName must be a string")
	assert(layer.Unit == nil or type(layer.Unit) == "string", "Layer.Unit must be a string")
	assert(layer.Color == nil or typeof(layer.Color) == "Color3", "Layer.Color must be a Color3")
	assert(layer.IncludeInAll == nil or type(layer.IncludeInAll) == "boolean", "Layer.IncludeInAll must be a boolean")
	assert(layer.ScaleValues == nil or type(layer.ScaleValues) == "table", "Layer.ScaleValues must be a table")
	if layer.ScaleValues then
		assert(#layer.ScaleValues > 0, "Layer.ScaleValues must not be empty")
		for _, value in layer.ScaleValues do
			assert(isPositiveFinite(value), "Layer.ScaleValues must contain positive finite numbers")
		end
	end
	assert(
		layer.DefaultMaxFrameValue == nil or isPositiveFinite(layer.DefaultMaxFrameValue),
		"Layer.DefaultMaxFrameValue must be positive and finite"
	)
end

function LayerRegistry.new(contextFactory)
	return setmetatable({
		_contextFactory = contextFactory,
		_layers = {},
		_order = {},
		_running = false,
		LayerAdded = Signal.new(),
		LayerRemoved = Signal.new(),
	}, LayerRegistry)
end

function LayerRegistry:_startLayer(layer)
	if layer.Start == nil or layer._cleanup ~= nil then
		return
	end

	local ok, cleanup = pcall(layer.Start, self._contextFactory(layer))
	if not ok then
		warn(string.format("PacketProfiler layer %q failed to start: %s", layer.Id, cleanup))
		return
	end

	layer._cleanup = cleanup or false
end

function LayerRegistry:_stopLayer(layer)
	if layer._cleanup then
		Cleanup.run(layer._cleanup)
	end
	layer._cleanup = nil
end

function LayerRegistry:Register(layer)
	validateLayer(layer)
	assert(self._layers[layer.Id] == nil, string.format("Layer %q is already registered", layer.Id))

	local registeredLayer = table.clone(layer)
	registeredLayer._cleanup = nil

	self._layers[layer.Id] = registeredLayer
	table.insert(self._order, registeredLayer)

	if self._running then
		self:_startLayer(registeredLayer)
	end

	self.LayerAdded:Fire(registeredLayer)

	local disconnected = false
	return {
		Disconnect = function()
			if disconnected then
				return
			end
			disconnected = true
			self:Unregister(layer.Id)
		end,
	}
end

function LayerRegistry:Unregister(layerId)
	local layer = self._layers[layerId]
	if layer == nil then
		return false
	end

	self:_stopLayer(layer)
	self._layers[layerId] = nil

	local index = table.find(self._order, layer)
	if index then
		table.remove(self._order, index)
	end

	self.LayerRemoved:Fire(layer)
	return true
end

function LayerRegistry:Get(layerId)
	return self._layers[layerId]
end

function LayerRegistry:GetAll()
	return table.clone(self._order)
end

function LayerRegistry:Start()
	if self._running then
		return
	end

	self._running = true
	for _, layer in self._order do
		self:_startLayer(layer)
	end
end

function LayerRegistry:Stop()
	if not self._running then
		return
	end

	self._running = false
	for _, layer in self._order do
		self:_stopLayer(layer)
	end
end

function LayerRegistry:Destroy()
	self:Stop()
	self.LayerAdded:DisconnectAll()
	self.LayerRemoved:DisconnectAll()
	table.clear(self._layers)
	table.clear(self._order)
end

return LayerRegistry
