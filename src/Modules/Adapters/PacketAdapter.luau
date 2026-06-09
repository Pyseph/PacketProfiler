--[[
	Adapter for 5uphi's "Packet" networking library.
	https://devforum.roblox.com/t/packet-networking-library/3573907

	Packet batches every event through a single RemoteEvent and serializes all data
	into one buffer, so without this adapter PacketProfiler only ever shows
	"Packet.RemoteEvent". This adapter decodes that buffer back into the individual
	named packets it contained.

	How it works (no private state required):
	  * Packet assigns each packet an id and stores the name->id map as ATTRIBUTES on
	    its RemoteEvent (`remoteEvent:SetAttribute(name, id)`). Those attributes are
	    public and replicate, so we read them straight off the captured remote to get
	    id -> name.
	  * The wire format is `[id:u8]` followed by the packet's serialized parameters,
	    with an extra `[threadIndex:u8]` for request/response packets. We walk the
	    buffer exactly like Packet's own receive loop, using Packet's stateless `Types`
	    readers to consume each packet's parameters and find the next id.

	Studio-plugin note: a plugin requires ModuleScripts in an isolated Lua VM, so our
	`require(Packet)` is a *separate* instance from the game's and its packet table is
	empty. The id->name map still works (it's read from the live remote's attributes),
	but parameter readers come from the game's packet definitions, which the isolated
	instance lacks. When that happens the walk desyncs and we bail (returning nil so
	the profiler falls back to "Packet.RemoteEvent"). For full per-packet decoding,
	run the in-game build (rbxm/Wally) where the profiler shares the game's VM.
]]

local PacketAdapter = {}
local DEBUG = true
local PACKET_MODULE_PATH: (() -> Instance?)? = nil

local PACKET_MODULE_NAMES = { "Packet" }

local SEARCH_CONTAINERS = {
	game:GetService("ReplicatedStorage"),
	game:GetService("ReplicatedFirst"),
	game:GetService("StarterPlayer"),
	game:GetService("Workspace"),
}

local debugDecodeLogs = 0

local function DebugLog(...)
	if DEBUG then
		warn("[PacketProfiler/Packet]", ...)
	end
end

local function FindPacketModule(): Instance?
	if PACKET_MODULE_PATH then
		local ok, result = pcall(PACKET_MODULE_PATH)
		if ok and typeof(result) == "Instance" then
			DebugLog("Using explicit PACKET_MODULE_PATH:", result:GetFullName())
			return result
		end
		DebugLog("PACKET_MODULE_PATH did not return an Instance:", result)
	end

	for _, container in SEARCH_CONTAINERS do
		for _, name in PACKET_MODULE_NAMES do
			local found = container:FindFirstChild(name, true)
			if found and found:IsA("ModuleScript") then
				DebugLog("Found Packet module by name:", found:GetFullName())
				return found
			end
		end
	end

	DebugLog(
		"Could not find the Packet module by name. If it's renamed/obfuscated, set "
			.. "PACKET_MODULE_PATH at the top of Adapters/Packet.luau."
	)
	return nil
end

function PacketAdapter.Start(env)
	local PacketModule = FindPacketModule()
	if not PacketModule then
		return nil -- Packet isn't used in this game.
	end

	local okPacket, Packet = pcall(require, PacketModule :: any)
	if not okPacket then
		warn(`[PacketProfiler] Packet adapter: failed to require "{PacketModule:GetFullName()}": {Packet}`)
		return nil
	end

	local TypesModule = PacketModule:FindFirstChild("Types")
	local okTypes, Types = pcall(require, TypesModule :: any)
	if not okTypes or typeof(Types) ~= "table" then
		warn(`[PacketProfiler] Packet adapter: couldn't require the Types module under "{PacketModule:GetFullName()}".`)
		return nil
	end

	local Import = Types.Import
	local Ended = Types.Ended
	local ReadU8 = Types.Reads and Types.Reads.NumberU8
	if typeof(Import) ~= "function" or typeof(Ended) ~= "function" or typeof(ReadU8) ~= "function" then
		warn("[PacketProfiler] Packet adapter: Types module is missing Import/Ended/Reads.NumberU8 (different Packet version?).")
		return nil
	end

	local function GetPacket(name: string)
		local ok, packet = pcall(Packet, name)
		if ok and typeof(packet) == "table" then
			return packet
		end
		return nil
	end

	local function ReadAll(readers): { any }
		local values = table.create(#readers)
		for index, reader in readers do
			values[index] = reader()
		end
		return values
	end

	local function Decode(remote: Instance, runContext, ...): { any }?
		local payload = table.pack(...)
		local data: buffer, instances
		if runContext == "Client" then
			data, instances = payload[1], payload[2] -- (buffer, instances)
		else
			data, instances = payload[2], payload[3] -- (player, buffer, instances)
		end
		if typeof(data) ~= "buffer" then
			return nil
		end
		local idToName = {}
		for name, id in remote:GetAttributes() do
			if type(id) == "number" then
				idToName[id] = name
			end
		end
		local myCursor = {
			Buffer = data,
			BufferLength = buffer.len(data),
			BufferOffset = 0,
			Instances = instances or {},
			InstancesOffset = 0,
		}
		Import(myCursor)
		local calls = {}
		local guard = 0
		local offsetsTracked = false
		local okWalk, reason = pcall(function()
			while Ended() == false do
				guard += 1
				if guard > 16384 then
					error("guard limit", 0)
				end

				local startOffset = myCursor.BufferOffset

				local id = ReadU8()
				local name = idToName[id]
				if name == nil then
					error(`unknown id {id}`, 0)
				end

				local packet = GetPacket(name)
				if not packet or typeof(packet.Reads) ~= "table" then
					error(`no readers for "{name}"`, 0)
				end

				local arguments
				if packet.ResponseReads then
					local threadIndex = ReadU8()
					if threadIndex < 128 then
						arguments = ReadAll(packet.Reads)
					else
						arguments = ReadAll(packet.ResponseReads)
					end
				else
					arguments = ReadAll(packet.Reads)
				end
				local raw
				local endOffset = myCursor.BufferOffset
				if endOffset > startOffset then
					offsetsTracked = true
					raw = buffer.create(endOffset - startOffset)
					buffer.copy(raw, 0, data, startOffset, endOffset - startOffset)
				end

				if DEBUG and debugDecodeLogs < 40 then
					debugDecodeLogs += 1
					DebugLog(`decoded "{name}": {#packet.Reads} reader(s) -> {#arguments} value(s), {endOffset - startOffset} byte(s)`)
				end

				table.insert(calls, { Name = name, Arguments = arguments, Raw = raw })
			end
		end)

		if not okWalk and DEBUG then
			DebugLog(`Stopped after {#calls} call(s) decoding a {buffer.len(data)}-byte buffer on {remote.Name}: {reason}`)
		end
		if not offsetsTracked and #calls > 0 then
			local full = buffer.create(buffer.len(data))
			buffer.copy(full, 0, data, 0, buffer.len(data))
			for _, call in calls do
				call.Raw = full
			end
		end

		return calls
	end
	local managedCount = 0
	for _, descendant in PacketModule:GetDescendants() do
		if descendant:IsA("RemoteEvent") or descendant:IsA("UnreliableRemoteEvent") then
			env.MarkManaged(descendant, Decode)
			managedCount += 1
			local attributeCount = 0
			for _ in descendant:GetAttributes() do
				attributeCount += 1
			end
			DebugLog(`Managed remote {descendant:GetFullName()} ({attributeCount} packet attribute(s))`)
		end
	end

	if managedCount == 0 then
		DebugLog("No RemoteEvent found under the Packet module; nothing to decode.")
	else
		DebugLog(`Decoder registered for {managedCount} remote(s). RunContext = {env.RunContext}.`)
	end

	return nil
end

return PacketAdapter
