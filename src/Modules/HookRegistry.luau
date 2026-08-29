local VALID_STAGES = {
	BeforeRecord = true,
	AfterRecord = true,
	FrameCommitted = true,
}

local HookRegistry = {}
HookRegistry.__index = HookRegistry

function HookRegistry.new()
	return setmetatable({
		_hooks = {
			BeforeRecord = {},
			AfterRecord = {},
			FrameCommitted = {},
		},
	}, HookRegistry)
end

function HookRegistry:Register(stage, callback)
	assert(VALID_STAGES[stage], string.format("Unknown hook stage %q", tostring(stage)))
	assert(type(callback) == "function", "Hook callback must be a function")

	local hooks = self._hooks[stage]
	table.insert(hooks, callback)

	local connected = true
	return {
		Disconnect = function()
			if not connected then
				return
			end
			connected = false
			local index = table.find(hooks, callback)
			if index then
				table.remove(hooks, index)
			end
		end,
	}
end

function HookRegistry:Run(stage, ...)
	for _, hook in self._hooks[stage] do
		local result = table.pack(pcall(hook, ...))
		if not result[1] then
			warn(string.format("PacketProfiler %s hook failed: %s", stage, tostring(result[2])))
		end
	end
end

function HookRegistry:Transform(stage, value)
	local current = value
	for _, hook in self._hooks[stage] do
		local ok, result = pcall(hook, current)
		if not ok then
			warn(string.format("PacketProfiler %s hook failed: %s", stage, tostring(result)))
		elseif result == false then
			return false
		elseif type(result) == "table" then
			current = result
		end
	end
	return current
end

function HookRegistry:Destroy()
	for _, hooks in self._hooks do
		table.clear(hooks)
	end
end

return HookRegistry
