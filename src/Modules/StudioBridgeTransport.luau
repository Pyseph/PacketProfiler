local PluginConnectionService = game:GetService("PluginConnectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PacketProfiler = script.Parent.Parent
local BridgeProtocol = require(PacketProfiler.Modules.BridgeProtocol)
local BridgeReceiver = require(PacketProfiler.Modules.BridgeReceiver)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local StudioBridgeTransport = {}

local MAX_PENDING_MESSAGES = 256

local function getBridgeEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if
		existing
		and existing:IsA("BindableEvent")
		and existing:GetAttribute(BridgeProtocol.OwnerAttribute) == true
		and existing:GetAttribute(BridgeProtocol.VersionAttribute) == BridgeProtocol.Version
	then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local event = Instance.new("BindableEvent")
	event.Name = name
	event.Archivable = false
	event:SetAttribute(BridgeProtocol.OwnerAttribute, true)
	event:SetAttribute(BridgeProtocol.VersionAttribute, BridgeProtocol.Version)
	event.Parent = ReplicatedStorage
	return event
end

function StudioBridgeTransport.Start(profiler)
	local inbound = getBridgeEvent(BridgeProtocol.EventName)
	local outbound = getBridgeEvent(BridgeProtocol.OutboundName)
	local connections = {}
	local connectionCleanups = {}
	local pendingMessages = {}
	local stopped = false
	local editCapture = {}
	local function updateCapture()
		local capturing = profiler:IsCapturing()
		for connection, enabled in editCapture do
			capturing = capturing or (connection.Connected and enabled)
		end
		inbound:SetAttribute(BridgeProtocol.CaptureAttribute, capturing)
	end
	updateCapture()
	table.insert(connections, profiler.CaptureChanged:Connect(updateCapture))
	local receiver = BridgeReceiver.new(profiler, function(_, registrationId, accepted, message)
		outbound:Fire(BridgeProtocol.RegistrationResult, registrationId, accepted, message)
	end)

	local function getEditConnection()
		for connection in connectionCleanups do
			if connection.Connected then
				return connection
			end
		end
		return nil
	end

	local function send(payload)
		local connection = getEditConnection()
		if connection then
			connection:SendMessage(payload)
			return
		end
		if #pendingMessages == MAX_PENDING_MESSAGES then
			table.remove(pendingMessages, 1)
		end
		table.insert(pendingMessages, payload)
	end

	local function flush(connection)
		if not connection.Connected then
			return
		end
		connection:SendMessage(BridgeProtocol.EncodeArguments(BridgeProtocol.RequestCaptureState))
		for _, payload in pendingMessages do
			connection:SendMessage(payload)
		end
		table.clear(pendingMessages)
	end

	local function attach(connection)
		if stopped or connection.Type ~= Enum.PluginConnectionTargetType.Edit or connectionCleanups[connection] then
			return
		end

		local cleanup = {}
		connectionCleanups[connection] = cleanup
		table.insert(
			cleanup,
			connection:BindToMessage(function(payload)
				local result = table.pack(pcall(BridgeProtocol.DecodeArguments, payload))
				if result[1] then
					if result[2] == BridgeProtocol.CaptureChanged then
						editCapture[connection] = result[3] == true
						updateCapture()
					else
						outbound:Fire(table.unpack(result, 2, result.n))
					end
				end
			end)
		)
		table.insert(
			cleanup,
			connection:GetPropertyChangedSignal("Connected"):Connect(function()
				if not connection.Connected then
					editCapture[connection] = nil
				end
				updateCapture()
				if connection.Connected then
					flush(connection)
				end
			end)
		)
		flush(connection)
	end

	table.insert(
		connections,
		inbound.Event:Connect(function(...)
			receiver:Receive("play-client", ...)
			if ... == BridgeProtocol.RecordBatch then
				local connection = getEditConnection()
				if not connection or not editCapture[connection] then
					return
				end
			end
			send(BridgeProtocol.EncodeArguments(...))
		end)
	)
	table.insert(connections, PluginConnectionService.Connected:Connect(attach))
	for _, connection in PluginConnectionService:GetPluginConnectionsOfType(Enum.PluginConnectionTargetType.Edit) do
		attach(connection)
	end

	return function()
		stopped = true
		inbound:SetAttribute(BridgeProtocol.CaptureAttribute, false)
		Cleanup.all(connections)
		for _, cleanup in connectionCleanups do
			Cleanup.all(cleanup)
		end
		receiver:Destroy()
		table.clear(connectionCleanups)
		table.clear(pendingMessages)
	end
end

return StudioBridgeTransport
