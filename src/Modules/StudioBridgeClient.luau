local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local PacketProfiler = script.Parent.Parent
local BridgeProtocol = require(PacketProfiler.Modules.BridgeProtocol)
local Cleanup = require(PacketProfiler.Modules.Cleanup)
local HookRegistry = require(PacketProfiler.Modules.HookRegistry)

local StudioBridgeClient = {}
StudioBridgeClient.__index = StudioBridgeClient

local function validateLayer(layer)
	assert(type(layer) == "table", "Layer must be a table")
	assert(type(layer.Id) == "string" and layer.Id ~= "", "Layer.Id must be a non-empty string")
	assert(type(layer.Name) == "string" and layer.Name ~= "", "Layer.Name must be a non-empty string")
	assert(layer.Start == nil or type(layer.Start) == "function", "Layer.Start must be a function")
end

local REGISTRATION_TIMEOUT = 3
local DEFAULT_DISCOVERY_TIMEOUT = 30

function StudioBridgeClient.new(waitSeconds)
	if not RunService:IsStudio() or not RunService:IsClient() then
		return nil
	end

	waitSeconds = if waitSeconds == nil then DEFAULT_DISCOVERY_TIMEOUT else waitSeconds
	local remote = ReplicatedStorage:FindFirstChild(BridgeProtocol.EventName)
	if remote == nil and waitSeconds and waitSeconds > 0 then
		remote = ReplicatedStorage:WaitForChild(BridgeProtocol.EventName, waitSeconds)
	end
	local outbound = ReplicatedStorage:FindFirstChild(BridgeProtocol.OutboundName)
	if outbound == nil and waitSeconds and waitSeconds > 0 then
		outbound = ReplicatedStorage:WaitForChild(BridgeProtocol.OutboundName, waitSeconds)
	end
	if
		remote == nil
		or not remote:IsA("BindableEvent")
		or remote:GetAttribute(BridgeProtocol.OwnerAttribute) ~= true
	then
		return nil
	end
	if outbound == nil or not outbound:IsA("BindableEvent") then
		return nil
	end
	if remote:GetAttribute(BridgeProtocol.VersionAttribute) ~= BridgeProtocol.Version then
		warn("PacketProfiler Studio bridge version mismatch; reinstall the plugin before profiling")
		return nil
	end

	local self = setmetatable({
		Mode = "StudioBridge",
		Remote = remote,
		Outbound = outbound,
		SessionId = HttpService:GenerateGUID(false),
		_layers = {},
		_addons = {},
		_hooks = HookRegistry.new(),
		_pendingRegistrations = {},
		_packetQueue = {},
		_destroyed = false,
	}, StudioBridgeClient)

	self._responseConnection = outbound.Event:Connect(function(command, registrationId, accepted, message)
		if command ~= BridgeProtocol.RegistrationResult then
			return
		end
		local pending = self._pendingRegistrations[registrationId]
		if pending then
			pending.Accepted = accepted == true
			pending.Message = message
			pending.Responded = true
		end
	end)
	self._captureConnection = remote:GetAttributeChangedSignal(BridgeProtocol.CaptureAttribute):Connect(function()
		if not self:IsCapturing() then
			table.clear(self._packetQueue)
			self:_flushPackets()
		end
		for _, handle in self._layers do
			handle.SetCapturing(self:IsCapturing())
		end
	end)

	return self
end

function StudioBridgeClient:IsCapturing()
	return not self._destroyed and self.Remote:GetAttribute(BridgeProtocol.CaptureAttribute) == true
end

function StudioBridgeClient:RegisterLayer(layer)
	validateLayer(layer)
	assert(self._layers[layer.Id] == nil, string.format("Layer %q is already registered", layer.Id))

	local registrationId = HttpService:GenerateGUID(false)
	local pending = {
		Accepted = false,
		Message = "registration timed out",
		Responded = false,
	}
	self._pendingRegistrations[registrationId] = pending
	self.Remote:Fire(
		BridgeProtocol.RegisterLayer,
		self.SessionId,
		registrationId,
		BridgeProtocol.CreateLayerDescriptor(layer)
	)
	local deadline = os.clock() + REGISTRATION_TIMEOUT
	while not pending.Responded and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	self._pendingRegistrations[registrationId] = nil
	if not pending.Accepted then
		error(string.format("Layer %q was rejected by the Studio plugin: %s", layer.Id, tostring(pending.Message)), 2)
	end
	self.Remote:SetAttribute("LastRegisteredLayer", layer.Id)

	local cleanup = nil
	local started = false
	local connected = true
	local handle
	handle = {
		RegistrationId = registrationId,
		SetCapturing = function(capturing)
			if not connected or started == capturing then
				return
			end
			started = capturing
			if cleanup then
				Cleanup.run(cleanup)
				cleanup = nil
			end
			if capturing and layer.Start then
				local ok, result = pcall(layer.Start, {
					Layer = layer,
					Profiler = self,
					Emit = function(packet)
						return self:Record(layer.Id, packet)
					end,
				})
				if not ok then
					handle:Disconnect()
					error(string.format("Layer %q failed to start: %s", layer.Id, tostring(result)), 2)
				end
				cleanup = result
			end
		end,
		Disconnect = function()
			if not connected then
				return
			end
			connected = false
			if cleanup then
				Cleanup.run(cleanup)
			end
			self:_flushPackets()
			self.Remote:Fire(BridgeProtocol.UnregisterLayer, self.SessionId, registrationId, layer.Id)
			self._layers[layer.Id] = nil
		end,
	}
	self._layers[layer.Id] = handle

	handle.SetCapturing(self:IsCapturing())
	return handle
end

function StudioBridgeClient:Record(layerId, packet)
	if not self:IsCapturing() then
		return false
	end
	assert(self._layers[layerId], string.format("Cannot record for unknown layer %q", tostring(layerId)))
	assert(type(packet) == "table", "Packet must be a table")
	assert(type(packet.Name) == "string", "Packet.Name must be a string")
	assert(type(packet.Size) == "number" and packet.Size >= 0, "Packet.Size must be a non-negative number")

	local handle = self._layers[layerId]
	local normalized = BridgeProtocol.CreatePacket(packet)
	normalized.LayerId = layerId
	local transformed = self._hooks:Transform("BeforeRecord", normalized)
	if transformed == false then
		return false
	end
	transformed.LayerId = layerId
	table.insert(self._packetQueue, {
		LayerId = layerId,
		RegistrationId = handle.RegistrationId,
		Packet = BridgeProtocol.CreatePacket(transformed),
	})
	if not self._flushConnection then
		self._flushConnection = RunService.Heartbeat:Connect(function()
			self:_flushPackets()
		end)
	end
	self._hooks:Run("AfterRecord", transformed)
	return true
end

function StudioBridgeClient:RegisterHook(stage, callback)
	return self._hooks:Register(stage, callback)
end

function StudioBridgeClient:_flushPackets()
	if self._flushConnection then
		self._flushConnection:Disconnect()
		self._flushConnection = nil
	end
	if #self._packetQueue == 0 or self._destroyed then
		return
	end
	local packets = self._packetQueue
	self._packetQueue = {}
	self.Remote:Fire(BridgeProtocol.RecordBatch, self.SessionId, packets)
end

function StudioBridgeClient:RegisterAddon(addon)
	assert(type(addon) == "table" and type(addon.Id) == "string", "Addon.Id must be a string")
	assert(type(addon.Install) == "function", "Addon.Install must be a function")
	assert(self._addons[addon.Id] == nil, string.format("Addon %q is already registered", addon.Id))

	local cleanup = addon.Install(self)
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

function StudioBridgeClient:Destroy()
	if self._destroyed then
		return
	end
	self:_flushPackets()
	self._destroyed = true
	for _, cleanup in self._addons do
		if cleanup then
			Cleanup.run(cleanup)
		end
	end
	table.clear(self._addons)

	local handles = {}
	for _, handle in self._layers do
		table.insert(handles, handle)
	end
	for _, handle in handles do
		handle:Disconnect()
	end
	self._captureConnection:Disconnect()
	self._responseConnection:Disconnect()
	self._hooks:Destroy()
end

return StudioBridgeClient
