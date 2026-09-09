local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)

local PacketSizeCounter = require(Packages.Directory.PacketSizeCounter)
local BridgeProtocol = require(PacketProfiler.Modules.BridgeProtocol)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local REMOTE_FUNCTION_EVENT_NAME = "RemoteFunctionEvent.profiler"
local DISCOVERY_BATCH_SIZE = 256
local DISCOVERY_TIME_BUDGET = 0.001

local function getContainers()
	local containers = {
		ReplicatedStorage,
		game:GetService("ReplicatedFirst"),
		game:GetService("StarterPlayer"),
		game:GetService("Workspace"),
		game:GetService("StarterGui"),
		game:GetService("Players"),
	}

	if RunService:IsServer() then
		table.insert(containers, game:GetService("ServerScriptService"))
		table.insert(containers, game:GetService("ServerStorage"))
	end

	return containers
end

local function isRemoteEvent(instance)
	if not instance:IsA("RemoteEvent") and not instance:IsA("UnreliableRemoteEvent") then
		return false
	end
	local isBridge = instance.Name == BridgeProtocol.EventName
		and instance:GetAttribute(BridgeProtocol.OwnerAttribute) == true
	return not isBridge
end

local function getPacketData(firstArgument, ...)
	if RunService:IsClient() then
		return { firstArgument, ... }
	end
	return { ... }
end

local function start(context)
	local connections = {}
	local connectedRemotes = {}
	local remoteContext = RunService:IsClient() and "OnClientEvent" or "OnServerEvent"
	local runContext = RunService:IsClient() and "Client" or "Server"
	local active = true

	local function record(remote, firstArgument, ...)
		if not active or not context.Profiler:IsCapturing() then
			return
		end
		local packetData = getPacketData(firstArgument, ...)
		local sizeDetails = PacketSizeCounter.GetPacketSizeDetails({
			RunContext = runContext,
			RemoteType = remote.ClassName,
			PacketData = packetData,
		})

		context.Emit({
			Name = remote:GetFullName(),
			Size = sizeDetails.Size,
			Data = packetData,
			RawData = { firstArgument, ... },
			Metadata = {
				Remote = remote,
				RunContext = runContext,
				UncompressedSize = sizeDetails.UncompressedSize,
				CompressionSavings = sizeDetails.CompressionSavings,
				CompressedBufferCount = sizeDetails.CompressedBufferCount,
			},
		})
	end

	local function connectRemote(remote)
		if not active or connectedRemotes[remote] then
			return
		end
		if isRemoteEvent(remote) then
			connectedRemotes[remote] = remote[remoteContext]:Connect(function(...)
				record(remote, ...)
			end)
		elseif remote:IsA("BindableEvent") and remote.Name == REMOTE_FUNCTION_EVENT_NAME then
			connectedRemotes[remote] = remote.Event:Connect(record)
		end
	end

	local containers = getContainers()
	for _, container in containers do
		table.insert(connections, container.DescendantAdded:Connect(connectRemote))
		table.insert(
			connections,
			container.DescendantRemoving:Connect(function(descendant)
				local connection = connectedRemotes[descendant]
				if connection then
					connection:Disconnect()
					connectedRemotes[descendant] = nil
				end
			end)
		)
	end

	-- Walk incrementally: neither a DataModel query nor a service-wide descendants array.
	local stack = {}
	for index = #containers, 1, -1 do
		local container = containers[index]
		table.insert(stack, { Children = { container }, Index = 1, Root = container })
	end
	local discoveryConnection
	discoveryConnection = RunService.Heartbeat:Connect(function()
		local deadline = os.clock() + DISCOVERY_TIME_BUDGET
		local visited = 0
		while active and #stack > 0 and visited < DISCOVERY_BATCH_SIZE and os.clock() < deadline do
			local cursor = stack[#stack]
			local instance = cursor.Children[cursor.Index]
			if instance == nil then
				table.remove(stack)
			else
				cursor.Index += 1
				visited += 1
				if instance == cursor.Root or instance:IsDescendantOf(cursor.Root) then
					connectRemote(instance)
					table.insert(stack, { Children = instance:GetChildren(), Index = 1, Root = cursor.Root })
				end
			end
		end
		if #stack == 0 then
			discoveryConnection:Disconnect()
		end
	end)
	table.insert(connections, discoveryConnection)

	return function()
		active = false
		Cleanup.all(connections)
		for _, connection in connectedRemotes do
			connection:Disconnect()
		end
		table.clear(connectedRemotes)
		table.clear(stack)
	end
end

return {
	Id = "remotes",
	Name = "Remotes",
	Description = "RemoteEvent, UnreliableRemoteEvent, and instrumented RemoteFunction traffic",
	Color = Color3.fromHex("#4CC2FF"),
	Start = start,
}
