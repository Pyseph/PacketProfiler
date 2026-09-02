local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Components = script.Components
local Modules = script.Modules

local MainPlugin = require(Components.MainPlugin)
local Profiler = require(Modules.Profiler)
local RemoteLayer = require(Modules.RemoteLayer)
local StudioBridgeClient = require(Modules.StudioBridgeClient)

local OPEN_ACTION = "PacketProfilerOpen"

local studioBridge = StudioBridgeClient.new()
if studioBridge then
	return studioBridge
end

local profiler = Profiler.new()
profiler:RegisterLayer(RemoteLayer)
local unmount
local starting = false

local function start()
	profiler:Start()
	unmount = MainPlugin({
		InitialProfilerEnabled = true,
		Profiler = profiler,
	})
end

ContextActionService:BindAction(OPEN_ACTION, function(_, inputState)
	if starting
		or inputState ~= Enum.UserInputState.Begin
		or not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
	then
		return Enum.ContextActionResult.Pass
	end

	starting = true
	ContextActionService:UnbindAction(OPEN_ACTION)
	task.defer(start)
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.F5)

local destroy = profiler.Destroy
function profiler:Destroy()
	ContextActionService:UnbindAction(OPEN_ACTION)
	local currentUnmount = unmount
	unmount = nil
	if currentUnmount then
		currentUnmount()
	end
	destroy(self)
end

profiler.Unmount = function()
	profiler:Destroy()
end

return profiler
