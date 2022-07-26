local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Plugin = script:FindFirstAncestorOfClass("Plugin")

local Components = script.Components
local Packages = script.Packages

local Roact = require(Packages.Roact)
local MainPlugin = require(Components.MainPlugin)

local Toolbar = Plugin:CreateToolbar("Packet Profiler")

local PacketProfiler = Toolbar:CreateButton("Open Profiler", "Open Profiler Graph", "rbxassetid://10283407097")
local PacketChart = Toolbar:CreateButton("Open Chart", "Open Pie Chart", "rbxassetid://10283406077")

local Main = Roact.createElement(MainPlugin, {
	PacketProfiler = PacketProfiler,
	PacketChart = PacketChart,
})

local Handle = Roact.mount(Main, nil, "PacketProfiler")

Plugin.Unloading:Connect(function()
	Roact.unmount(Handle)
end)