local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)

local PacketSizeCounter = require(Packages.Directory.PacketSizeCounter)
local BridgeProtocol = require(PacketProfiler.Modules.BridgeProtocol)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local REMOTE_FUNCTION_EVENT_NAME = "RemoteFunctionEvent.profiler"

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
	local isBridge = instance.Name == BridgeProtocol.EventName
		and instance:GetAttribute(BridgeProtocol.OwnerAttribute) == true
	return not isBridge and (instance:IsA("RemoteEvent") or instance:IsA("UnreliableRemoteEvent"))
end

local function getPacketData(firstArgument, ...)
	if RunService:IsClient() then
		return { firstArgument, ... }
	end
	return { ... }
end

local function start(context)
	local connections = {}
	local connectedRemotes = setmetatable({}, { __mode = "k" })
	local remoteContext = RunService:IsClient() and "OnClientEvent" or "OnServerEvent"
	local active = true

	local function record(remote, firstArgument, ...)
		local packetData = getPacketData(firstArgument, ...)
		local size = PacketSizeCounter.GetPacketSize({
			RunContext = RunService:IsClient() and "Client" or "Server",
			RemoteType = remote.ClassName,
			PacketData = packetData,
		})

		context.Emit({
			Name = string.format("%s.%s", remote.Parent:GetFullName(), remote.Name),
			Size = size,
			Data = packetData,
			RawData = { firstArgument, ... },
			Metadata = {
				Remote = remote,
				RunContext = RunService:IsClient() and "Client" or "Server",
			},
		})
	end

	local function connectRemote(remote)
		if not active or connectedRemotes[remote] then
			return
		end
		connectedRemotes[remote] = true
		table.insert(
			connections,
			remote[remoteContext]:Connect(function(...)
				record(remote, ...)
			end)
		)
	end

	for _, container in getContainers() do
		table.insert(
			connections,
			container.DescendantAdded:Connect(function(descendant)
				if isRemoteEvent(descendant) then
					connectRemote(descendant)
				elseif descendant:IsA("BindableEvent") and descendant.Name == REMOTE_FUNCTION_EVENT_NAME then
					table.insert(connections, descendant.Event:Connect(record))
				end
			end)
		)
	end

	task.defer(function()
		for _, container in getContainers() do
			if not active then
				return
			end
			for _, descendant in container:GetDescendants() do
				if isRemoteEvent(descendant) then
					connectRemote(descendant)
				end
			end
		end
	end)

	local remoteFunctionEvent = ReplicatedStorage:FindFirstChild(REMOTE_FUNCTION_EVENT_NAME, true)
	if remoteFunctionEvent and remoteFunctionEvent:IsA("BindableEvent") then
		table.insert(connections, remoteFunctionEvent.Event:Connect(record))
	end

	return function()
		active = false
		Cleanup.all(connections)
	end
end

return {
	Id = "remotes",
	Name = "Remotes",
	Description = "RemoteEvent, UnreliableRemoteEvent, and instrumented RemoteFunction traffic",
	Color = Color3.fromHex("#4CC2FF"),
	Start = start,
}
