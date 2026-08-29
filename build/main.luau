local Components = script.Components
local Modules = script.Modules

local MainPlugin = require(Components.MainPlugin)
local Profiler = require(Modules.Profiler)
local RemoteLayer = require(Modules.RemoteLayer)
local StudioBridgeClient = require(Modules.StudioBridgeClient)

local studioBridge = StudioBridgeClient.new()
if studioBridge then
	return studioBridge
end

local profiler = Profiler.new()
profiler:RegisterLayer(RemoteLayer)
profiler:Start()

local unmount = MainPlugin({
	Profiler = profiler,
})

profiler.Unmount = function()
	unmount()
	profiler:Destroy()
end

return profiler
