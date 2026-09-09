-- Run with: lune run tests/performance.luau
-- Engine signals and instance trees are mocked; modules under test are loaded unchanged.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local enums = { PluginConnectionTargetType = { Edit = "Edit", Test = "Test" } }

local Signal = {}
function Signal.new()
	local self = { listeners = {} }
	function self:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect()
			self.Connected = false
		end
		self.listeners[connection] = callback
		return connection
	end
	function self:Fire(...)
		for connection, callback in table.clone(self.listeners) do
			if connection.Connected then
				callback(...)
			end
		end
	end
	function self:DisconnectAll()
		for connection in self.listeners do
			connection:Disconnect()
		end
	end
	function self:Count()
		local count = 0
		for connection in self.listeners do
			if connection.Connected then
				count += 1
			end
		end
		return count
	end
	return self
end

local childReads = 0
local function instance(class, name, parent)
	local self = {
		ClassName = class,
		Name = name or class,
		Parent = parent,
		Children = {},
		Attributes = {},
		AttributeSignals = {},
		DescendantAdded = Signal.new(),
		DescendantRemoving = Signal.new(),
		Event = Signal.new(),
		OnClientEvent = Signal.new(),
	}
	if parent then
		table.insert(parent.Children, self)
	end
	function self:IsA(kind)
		return self.ClassName == kind
	end
	function self:GetAttribute(key)
		return self.Attributes[key]
	end
	function self:SetAttribute(key, value)
		self.Attributes[key] = value
		if self.AttributeSignals[key] then
			self.AttributeSignals[key]:Fire()
		end
	end
	function self:GetAttributeChangedSignal(key)
		self.AttributeSignals[key] = self.AttributeSignals[key] or Signal.new()
		return self.AttributeSignals[key]
	end
	function self:GetChildren()
		childReads += 1
		return table.clone(self.Children)
	end
	function self:GetDescendants()
		error("Unbounded GetDescendants scan")
	end
	function self:QueryDescendants()
		error("Unbounded QueryDescendants scan")
	end
	function self:IsDescendantOf(root)
		local current = self.Parent
		while current do
			if current == root then
				return true
			end
			current = current.Parent
		end
		return false
	end
	function self:GetFullName()
		return self.Name
	end
	function self:FindFirstChild(key)
		for _, child in self.Children do
			if child.Name == key then
				return child
			end
		end
		return nil
	end
	function self:Fire(...)
		self.Event:Fire(...)
	end
	function self:Destroy()
		self.Parent = nil
	end
	return self
end

local run = { Heartbeat = Signal.new(), RenderStepped = Signal.new() }
function run:IsClient()
	return true
end
function run:IsServer()
	return false
end
function run:IsStudio()
	return true
end
local guid = 0
local services = {
	RunService = run,
	HttpService = {
		GenerateGUID = function()
			guid += 1
			return tostring(guid)
		end,
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end,
		JSONDecode = function(_, value)
			return serde.decode("json", value)
		end,
	},
}
for _, name in { "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "Workspace", "StarterGui", "Players" } do
	services[name] = instance("Folder", name)
end
local modules = setmetatable({}, {
	__index = function(_, name)
		return name
	end,
})
local sizeCalls = 0
local cache = {
	Packages = { Directory = { Signal = "Signal", PacketSizeCounter = "PacketSizeCounter" } },
	Signal = Signal,
	PacketSizeCounter = {
		GetPacketSizeDetails = function()
			sizeCalls += 1
			return { Size = 10 }
		end,
	},
}
local loadModule
loadModule = function(name)
	if cache[name] then
		return cache[name]
	end
	local result = luau.load(fs.readFile("src/Modules/" .. name .. ".luau"), {
		debugName = name,
		environment = {
			script = { Parent = { Parent = { Modules = modules } } },
			require = loadModule,
			game = {
				GetService = function(_, key)
					assert(services[key], key)
					return services[key]
				end,
			},
			Color3 = roblox.Color3,
			Enum = enums,
			Instance = {
				new = function(class)
					return instance(class)
				end,
			},
		},
	})()
	cache[name] = result
	return result
end

local Profiler = loadModule("Profiler")
local RemoteLayer = loadModule("RemoteLayer")
local remote = instance("RemoteEvent", "Remote", services.ReplicatedStorage)
local instrumented = instance("BindableEvent", "RemoteFunctionEvent.profiler", services.ReplicatedStorage)
for index = 1, 2000 do
	instance("Folder", tostring(index), services.Workspace)
end
local profiler = Profiler.new()
profiler:RegisterLayer(RemoteLayer)
assert(
	childReads == 0 and run.Heartbeat:Count() == 0 and run.RenderStepped:Count() == 0,
	"Idle initialization performs work"
)
assert(profiler:Record("remotes", {}) == false, "Idle packets accepted")
profiler:Start()
profiler:Start()
assert(childReads == 0 and run.Heartbeat:Count() == 1 and run.RenderStepped:Count() == 1)
run.Heartbeat:Fire()
assert(childReads <= 256, "Discovery exceeded its instance budget")
assert(remote.OnClientEvent:Count() == 1 and instrumented.Event:Count() == 1)
services.ReplicatedStorage.DescendantAdded:Fire(remote)
services.ReplicatedStorage.DescendantAdded:Fire(instrumented)
remote.OnClientEvent:Fire("packet")
instrumented.Event:Fire(remote, "packet")
assert(sizeCalls == 2, "Duplicate instrumentation or remote subscription")
local topChanges = 0
profiler.TopFramesChanged:Connect(function()
	topChanges += 1
end)
local baseTime = profiler._frames.NextBucket / 60
for index = 0, 3 do
	profiler:Record("remotes", { Name = "batch", Size = 10, Timestamp = baseTime + index / 60 + 0.001 })
end
run.RenderStepped:Fire(4 / 60)
assert(topChanges == 1, "Top spikes refreshed more than once per batch")
local retained = #profiler.Frames
profiler:Stop()
assert(run.Heartbeat:Count() == 0 and run.RenderStepped:Count() == 0)
assert(remote.OnClientEvent:Count() == 0 and instrumented.Event:Count() == 0)
local readsAtStop = childReads
run.Heartbeat:Fire()
remote.OnClientEvent:Fire("ignored")
assert(childReads == readsAtStop and sizeCalls == 2, "Stopped work continued")
for _, service in services do
	if service.DescendantAdded then
		assert(service.DescendantAdded:Count() == 0 and service.DescendantRemoving:Count() == 0)
	end
end
profiler:Start()
while run.Heartbeat:Count() > 0 do
	run.Heartbeat:Fire()
end
assert(remote.OnClientEvent:Count() == 1 and #profiler.Frames == retained)
services.ReplicatedStorage.DescendantRemoving:Fire(remote)
assert(remote.OnClientEvent:Count() == 0)
remote.Parent = services.Workspace
services.Workspace.DescendantAdded:Fire(remote)
assert(remote.OnClientEvent:Count() == 1)
profiler:SetPaused(true)
assert(run.Heartbeat:Count() == 0 and run.RenderStepped:Count() == 0)
profiler:SetPaused(false)
assert(run.Heartbeat:Count() == 1 and run.RenderStepped:Count() == 1)
profiler:Stop()
profiler:SetPaused(true)
profiler:SetPaused(false)
assert(run.Heartbeat:Count() == 0 and run.RenderStepped:Count() == 0, "Unpausing closed profiler restarted capture")
profiler:Destroy()
print(
	"PASS: idle, bounded discovery, cancellation, deduplication, reparenting, pause/resume, retained frames, batched ranking"
)

local protocol = loadModule("BridgeProtocol")
local inbound = instance("BindableEvent", protocol.EventName, services.ReplicatedStorage)
local outbound = instance("BindableEvent", protocol.OutboundName, services.ReplicatedStorage)
inbound:SetAttribute(protocol.OwnerAttribute, true)
inbound:SetAttribute(protocol.VersionAttribute, protocol.Version)
inbound:SetAttribute(protocol.CaptureAttribute, false)
local batches = 0
inbound.Event:Connect(function(command, _, registrationId)
	if command == protocol.RegisterLayer then
		outbound:Fire(protocol.RegistrationResult, registrationId, true)
	end
	if command == protocol.RecordBatch then
		batches += 1
	end
end)
local client = loadModule("StudioBridgeClient").new(0)
assert(client and run.Heartbeat:Count() == 0)
local starts, stops = 0, 0
client:RegisterLayer({
	Id = "extension",
	Name = "Extension",
	Start = function()
		starts += 1
		return function()
			stops += 1
		end
	end,
})
assert(starts == 0, "Hidden bridge started extension adapter")
assert(client:Record("extension", {}) == false)
inbound:SetAttribute(protocol.CaptureAttribute, true)
assert(starts == 1)
client:Record("extension", { Name = "packet", Size = 1 })
client:Record("extension", { Name = "packet", Size = 1 })
assert(run.Heartbeat:Count() == 1)
run.Heartbeat:Fire()
assert(batches == 1 and run.Heartbeat:Count() == 0, "Bridge flush loop remained idle")
client:Record("extension", { Name = "packet", Size = 1 })
inbound:SetAttribute(protocol.CaptureAttribute, false)
assert(stops == 1 and run.Heartbeat:Count() == 0 and #client._packetQueue == 0)
inbound:SetAttribute(protocol.CaptureAttribute, true)
assert(starts == 2)
client:Destroy()
assert(stops == 2 and run.Heartbeat:Count() == 0)
print(
	"PASS: bridge adapters suspend/resume, inactive records drop, pending batches cancel, flush connection is demand-driven"
)

-- Exercise the actual Edit/Play transport in both startup orders.
local function transportTest(editFirst)
	cache.StudioBridge = nil
	cache.StudioBridgeTransport = nil
	local service = { Connected = Signal.new() }
	services.PluginConnectionService = service
	local function connection(kind)
		local self =
			{ Type = kind, TargetId = "test", Connected = true, Messages = Signal.new(), Changed = Signal.new() }
		function self:BindToMessage(callback)
			return self.Messages:Connect(callback)
		end
		function self:GetPropertyChangedSignal()
			return self.Changed
		end
		function self:SendMessage(payload)
			self.Peer.Messages:Fire(payload)
		end
		return self
	end
	local editConnection = connection(enums.PluginConnectionTargetType.Edit)
	local testConnection = connection(enums.PluginConnectionTargetType.Test)
	editConnection.Peer = testConnection
	testConnection.Peer = editConnection
	function service:GetPluginConnectionsOfType(kind)
		return { if kind == enums.PluginConnectionTargetType.Edit then editConnection else testConnection }
	end
	local editProfiler, playProfiler = Profiler.new(), Profiler.new()
	editProfiler:Start()
	local stopEdit, stopPlay
	if editFirst then
		stopEdit = loadModule("StudioBridge").Start(editProfiler)
		stopPlay = loadModule("StudioBridgeTransport").Start(playProfiler)
	else
		stopPlay = loadModule("StudioBridgeTransport").Start(playProfiler)
		stopEdit = loadModule("StudioBridge").Start(editProfiler)
	end
	assert(inbound:GetAttribute(protocol.CaptureAttribute) == true, "Initial capture handshake lost")
	editProfiler:Stop()
	assert(inbound:GetAttribute(protocol.CaptureAttribute) == false)
	playProfiler:Start()
	assert(inbound:GetAttribute(protocol.CaptureAttribute) == true)
	editProfiler:Start()
	playProfiler:Stop()
	assert(inbound:GetAttribute(protocol.CaptureAttribute) == true, "Local close overrode Edit capture demand")
	editConnection.Connected = false
	editConnection.Changed:Fire()
	assert(inbound:GetAttribute(protocol.CaptureAttribute) == false, "Disconnected Edit retained demand")
	editConnection.Connected = true
	editConnection.Changed:Fire()
	assert(inbound:GetAttribute(protocol.CaptureAttribute) == true, "Reconnect failed to restore demand")
	stopPlay()
	stopEdit()
	editProfiler:Destroy()
	playProfiler:Destroy()
	assert(inbound:GetAttribute(protocol.CaptureAttribute) == false)
end
transportTest(true)
transportTest(false)
print("PASS: Edit/Play handshake in either startup order, combined demand, disconnect/reconnect, transport cleanup")
