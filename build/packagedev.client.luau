local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Components = script.Components
local Modules = script.Modules
local Packages = require(Modules.Packages)
Packages.IsPlugin = false

local Roact = require(Packages.Directory.Roact)
local MainPlugin = require(Components.MainPlugin)

local Main = Roact.createElement(MainPlugin)

Roact.mount(Main, LocalPlayer.PlayerGui, "PacketProfiler")