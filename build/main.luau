local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
if RunService:IsStudio() then
	return nil
end

local LocalPlayer = Players.LocalPlayer

local Components = script.Components
local Modules = script.Modules
local Packages = require(Modules.Packages)

local Roact = require(Packages.Directory.Roact)
local MainPlugin = require(Components.MainPlugin)

local Main = Roact.createElement(MainPlugin)

Roact.mount(Main, LocalPlayer.PlayerGui, "PacketProfiler")
return nil