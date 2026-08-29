local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Plugin = script:FindFirstAncestorOfClass("Plugin")

local Components = script.Components
local Modules = script.Modules

local PluginConnectionService = game:GetService("PluginConnectionService")
local isTestDataModel = PluginConnectionService:CanHaveConnectionType(Enum.PluginConnectionTargetType.Edit)
if isTestDataModel and not RunService:IsClient() then
	return
end

local MainPlugin = require(Components.MainPlugin)
local Profiler = require(Modules.Profiler)
local RemoteLayer = require(Modules.RemoteLayer)
local StudioBridge = require(Modules.StudioBridge)

local Toolbar = Plugin:CreateToolbar("Packet Profiler")

local PacketProfiler = Toolbar:CreateButton("Open Profiler", "Open Profiler Graph", "rbxassetid://10283407097")
local PacketChart = Toolbar:CreateButton("Open Chart", "Open Pie Chart", "rbxassetid://10283406077")

local profiler = Profiler.new()
profiler:RegisterLayer(RemoteLayer)
profiler:Start()
local stopStudioBridge
if isTestDataModel then
	local StudioBridgeTransport = require(Modules.StudioBridgeTransport)
	stopStudioBridge = StudioBridgeTransport.Start(profiler)
else
	stopStudioBridge = StudioBridge.Start(profiler)
end

local unmount = MainPlugin({
	PacketProfilerButton = PacketProfiler,
	PacketChartButton = PacketChart,
	Plugin = Plugin,
	Profiler = profiler,
})

Plugin.Unloading:Connect(function()
	stopStudioBridge()
	unmount()
	profiler:Destroy()
end)
