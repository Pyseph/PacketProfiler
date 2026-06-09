--!strict
--[[
	Networking-library adapters.

	Batched networking libraries (Packet, ByteNet, Warp, ...) funnel every logical
	"remote" through a single RemoteEvent and serialize the payload into one buffer.
	PacketProfiler captures that RemoteEvent fire but can only label it by the
	RemoteEvent's name (e.g. "Packet.RemoteEvent"), so you can never tell *which*
	logical remote was actually sent.

	An adapter teaches PacketProfiler about one such library. At session start it
	registers a *decoder* for the library's RemoteEvent(s). When the user inspects a
	captured frame, PacketProfiler asks the decoder to turn that RemoteEvent's raw
	payload back into a list of named calls `{ {Name, Arguments}, ... }`. The chart
	then splits the real byte size across them by name -- the same shape the built-in
	`RemoteName.profiler` list return uses, but automatic and library-aware.

	To add support for a new library, drop a `<Name>.luau` ModuleScript next to this
	file that returns a table with a `Start(env)` function. See `Packet.luau` for a
	worked example. `env` provides:
		env.RunContext : "Client" | "Server"
		env.MarkManaged(remote: Instance, decoder: Decoder)
	`Start` should return a cleanup function (or nil).

	A Decoder is called with the captured RemoteEvent and the exact arguments that
	came over it, and returns the decoded calls (or nil to fall back to normal
	labeling):
		decoder(remote, runContext, ...) -> { Call }?
	`...` is the raw remote payload:
		Client receive: (payload, ...)            -- e.g. (buffer, instances)
		Server receive: (player, payload, ...)    -- OnServerEvent style
]]

export type Call = {
	Name: string,
	Arguments: { any },
}

export type Decoder = (remote: Instance, runContext: "Client" | "Server", ...any) -> { Call }?

export type AdapterEnv = {
	RunContext: "Client" | "Server",
	MarkManaged: (remote: Instance, decoder: Decoder) -> (),
}

export type Adapter = {
	Start: (env: AdapterEnv) -> (() -> ())?,
}

local Adapters = {}

-- RemoteEvents owned by a networking library, mapped to their decoder.
local Decoders: { [Instance]: Decoder } = {}

-- True if the remote is owned by a known networking library.
function Adapters.IsManaged(remote: Instance): boolean
	return Decoders[remote] ~= nil
end

-- Decode a captured managed-remote fire into named calls. Returns nil (so callers
-- fall back to normal labeling) for unmanaged remotes, decoder errors, or when the
-- decoder couldn't confidently decode the payload.
function Adapters.Decode(remote: Instance, runContext: "Client" | "Server", ...): { Call }?
	local decoder = Decoders[remote]
	if not decoder then
		return nil
	end

	local ok, result = pcall(decoder, remote, runContext, ...)
	if not ok then
		warn(`[PacketProfiler] Decoder for "{remote.Name}" errored: {result}`)
		return nil
	end
	if typeof(result) == "table" and #(result :: any) > 0 then
		return result :: any
	end
	return nil
end

-- Start every adapter for the given run context. Returns a cleanup function.
function Adapters.Start(runContext: "Client" | "Server"): () -> ()
	warn(`[PacketProfiler] Networking-library adapters starting (context: {runContext})`)

	local env: AdapterEnv = {
		RunContext = runContext,
		MarkManaged = function(remote: Instance, decoder: Decoder)
			Decoders[remote] = decoder
		end,
	}

	local cleanups: { () -> () } = {}

	for _, child in script:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end

		local okRequire, adapter = pcall(require, child :: any)
		if not okRequire then
			warn(`[PacketProfiler] Failed to require adapter "{child.Name}": {adapter}`)
			continue
		end
		if typeof(adapter) ~= "table" or typeof(adapter.Start) ~= "function" then
			continue
		end

		local okStart, cleanup = pcall(adapter.Start, env)
		if not okStart then
			warn(`[PacketProfiler] Adapter "{child.Name}" failed to start: {cleanup}`)
			continue
		end
		if typeof(cleanup) == "function" then
			table.insert(cleanups, cleanup)
		end
	end

	return function()
		for _, cleanup in cleanups do
			pcall(cleanup)
		end
		table.clear(Decoders)
	end
end

return Adapters
