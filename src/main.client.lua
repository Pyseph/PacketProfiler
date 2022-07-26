local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
if RunService:IsStudio() then
	return
end

local PacketProfiler = script:FindFirstAncestor("PacketProfiler")
local LocalPlayer = Players.LocalPlayer

local Components = PacketProfiler.Components
local Packages = PacketProfiler.Packages

local Roact = require(Packages.Roact)
local MainPlugin = require(Components.MainPlugin)

local Main = Roact.createElement(MainPlugin)

Roact.mount(Main, LocalPlayer.PlayerGui, "PacketProfiler")