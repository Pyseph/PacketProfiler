local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)

local PacketSizeCounter = require(Packages.Directory.PacketSizeCounter)
local TableToSyntaxString = require(PacketProfiler.Modules.TableToSyntaxString)

local REMOTE_NAME_MODULE_NAME = "RemoteName.profiler"
local GOLDEN_RATIO_CONJUGATE = 0.6180339887498948

local hue = 0
local remoteNameLabeler = nil

local function nextColor()
	hue = (hue + GOLDEN_RATIO_CONJUGATE) % 1
	return Color3.fromHSV(hue, 0.52, 0.96)
end

local function loadRemoteNameLabeler(module)
	local result = require(module)
	assert(typeof(result) == "function", "Return of RemoteName.profiler must be a function")
	remoteNameLabeler = result
end

local function getRemoteNameLabeler()
	if remoteNameLabeler == nil then
		local module = ReplicatedStorage:FindFirstChild(REMOTE_NAME_MODULE_NAME, true)
		if module and module:IsA("ModuleScript") then
			loadRemoteNameLabeler(module)
		end
	end
	return remoteNameLabeler
end

local function appendCall(groups, name, size, callName, data)
	local group = groups[name]
	if group == nil then
		group = { Size = 0, Data = {} }
		groups[name] = group
	end

	group.Size += size
	table.insert(group.Data, {
		Name = callName,
		Packet = data,
	})
end

local function addRemotePacket(groups, packet)
	local metadata = packet.Metadata
	local remote = metadata and metadata.Remote
	local labeler = getRemoteNameLabeler()
	local remoteData = remote and labeler and labeler(remote, unpack(packet.RawData or {}))

	if typeof(remoteData) ~= "table" then
		local name = typeof(remoteData) == "string" and remoteData or packet.Name
		local callIndex = groups[name] and #groups[name].Data + 1 or 1
		appendCall(
			groups,
			name,
			packet.Size,
			string.format("Remote call %d", callIndex),
			TableToSyntaxString(packet.Data or {})
		)
		return
	end

	local sizes = {}
	local totalSize = 0
	for index, call in remoteData do
		local size = PacketSizeCounter.GetPacketSize({
			RunContext = metadata.RunContext,
			RemoteType = "RemoteEvent",
			PacketData = call.Arguments,
		}) - PacketSizeCounter.BaseRemoteOverhead
		if metadata.RunContext == "Client" then
			size -= PacketSizeCounter.ClientToServerOverhead
		end
		sizes[index] = math.max(size, 0)
		totalSize += sizes[index]
	end

	for index, call in remoteData do
		local size = totalSize > 0 and sizes[index] / totalSize * packet.Size or packet.Size / #remoteData
		appendCall(groups, call.Name, size, call.Name, TableToSyntaxString(call.Arguments, true))
	end
end

local function addGenericPacket(groups, packet)
	appendCall(groups, packet.Name, packet.Size, packet.Name, TableToSyntaxString(packet.Data or {}))
end

local function build(frame)
	local groups = {}
	for _, packet in frame.Packets do
		if packet.LayerId == "remotes" then
			addRemotePacket(groups, packet)
		else
			addGenericPacket(groups, packet)
		end
	end

	local arcs = {}
	for name, group in groups do
		table.insert(arcs, {
			Name = name,
			DataSize = group.Size,
			Percent = frame.TotalSize > 0 and group.Size / frame.TotalSize * 100 or 0,
			Color = nextColor(),
			RemoteData = group.Data,
		})
	end

	table.sort(arcs, function(left, right)
		return left.DataSize > right.DataSize
	end)
	return arcs
end

return build
