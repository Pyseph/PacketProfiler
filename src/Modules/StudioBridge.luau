local PluginConnectionService = game:GetService("PluginConnectionService")
local RunService = game:GetService("RunService")

local PacketProfiler = script.Parent.Parent
local BridgeProtocol = require(PacketProfiler.Modules.BridgeProtocol)
local BridgeReceiver = require(PacketProfiler.Modules.BridgeReceiver)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local StudioBridge = {}

function StudioBridge.Start(profiler)
	if not RunService:IsStudio() then
		return function() end
	end

	local connections = {}
	local connectionCleanups = {}
	local targets = {}
	local stopped = false
	local function sendCaptureState(connection)
		if connection.Connected then
			connection:SendMessage(
				BridgeProtocol.EncodeArguments(BridgeProtocol.CaptureChanged, profiler:IsCapturing())
			)
		end
	end
	local receiver = BridgeReceiver.new(profiler, function(ownerId, registrationId, accepted, message)
		local connection = targets[ownerId]
		if connection and connection.Connected then
			connection:SendMessage(
				BridgeProtocol.EncodeArguments(BridgeProtocol.RegistrationResult, registrationId, accepted, message)
			)
		end
	end)

	local function detach(connection)
		local ownerId = connection.TargetId
		receiver:DisconnectOwner(ownerId)
		if targets[ownerId] == connection then
			targets[ownerId] = nil
		end
	end

	local function attach(connection)
		if stopped or connection.Type ~= Enum.PluginConnectionTargetType.Test or connectionCleanups[connection] then
			return
		end

		local ownerId = connection.TargetId
		local cleanup = {}
		targets[ownerId] = connection
		connectionCleanups[connection] = cleanup
		table.insert(
			cleanup,
			connection:BindToMessage(function(payload)
				local result = table.pack(pcall(BridgeProtocol.DecodeArguments, payload))
				if result[1] then
					if result[2] == BridgeProtocol.RequestCaptureState then
						sendCaptureState(connection)
					else
						receiver:Receive(ownerId, table.unpack(result, 2, result.n))
					end
				else
					warn("PacketProfiler bridge received an invalid message")
				end
			end)
		)
		table.insert(
			cleanup,
			connection:GetPropertyChangedSignal("Connected"):Connect(function()
				if not connection.Connected then
					detach(connection)
				else
					sendCaptureState(connection)
				end
			end)
		)
		sendCaptureState(connection)
	end

	table.insert(
		connections,
		profiler.CaptureChanged:Connect(function()
			for connection in connectionCleanups do
				sendCaptureState(connection)
			end
		end)
	)
	table.insert(connections, PluginConnectionService.Connected:Connect(attach))
	for _, connection in PluginConnectionService:GetPluginConnectionsOfType(Enum.PluginConnectionTargetType.Test) do
		attach(connection)
	end

	return function()
		stopped = true
		Cleanup.all(connections)
		for connection, cleanup in connectionCleanups do
			Cleanup.all(cleanup)
			detach(connection)
		end
		receiver:Destroy()
		table.clear(connectionCleanups)
		table.clear(targets)
	end
end

return StudioBridge
