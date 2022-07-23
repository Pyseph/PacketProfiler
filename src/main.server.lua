local Plugin = script:FindFirstAncestorOfClass("Plugin")

local Components = Plugin.PacketAnalyzer.Components
local Packages = Plugin.PacketAnalyzer.Packages

local Roact = require(Packages.Roact)
local MainPlugin = require(Components.MainPlugin)

local Toolbar = Plugin:CreateToolbar("Packet Analyzer")

local PacketProfiler = Toolbar:CreateButton("Packet Profiler", "Open Profiler Graph", "rbxassetid://10283407097")
local PacketChart = Toolbar:CreateButton("Packet Chart", "Open Pie Chart", "rbxassetid://10283406077")

local Main = Roact.createElement(MainPlugin, {
	PacketProfiler = PacketProfiler,
	PacketChart = PacketChart,
})

local Handle = Roact.mount(Main, nil, "PacketAnalyzer")

Plugin.Unloading:Connect(function()
	Roact.unmount(Handle)
end)