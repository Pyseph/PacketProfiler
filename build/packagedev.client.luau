local Components = script.Components
local Modules = script.Modules
local Packages = require(Modules.Packages)
Packages.IsPlugin = false

local MainPlugin = require(Components.MainPlugin)
local Profiler = require(Modules.Profiler)
local RemoteLayer = require(Modules.RemoteLayer)
local StudioBridgeClient = require(Modules.StudioBridgeClient)

local studioBridge = StudioBridgeClient.new()
if studioBridge then
	return
end

local profiler = Profiler.new()
profiler:RegisterLayer(RemoteLayer)
profiler:Start()

MainPlugin({
	Profiler = profiler,
})
