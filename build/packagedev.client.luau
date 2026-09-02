local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local OPEN_ACTION = "PacketProfilerOpen"
local Starting = false

local function Start()
	local Components = script.Components
	local Modules = script.Modules
	local Packages = require(Modules.Packages)
	Packages.IsPlugin = false

	local StudioBridgeClient = require(Modules.StudioBridgeClient)
	local StudioBridge = StudioBridgeClient.new()
	if StudioBridge then
		return
	end

	local MainPlugin = require(Components.MainPlugin)
	local Profiler = require(Modules.Profiler)
	local RemoteLayer = require(Modules.RemoteLayer)
	local ProfilerInstance = Profiler.new()
	ProfilerInstance:RegisterLayer(RemoteLayer)
	ProfilerInstance:Start()

	MainPlugin({
		InitialProfilerEnabled = true,
		Profiler = ProfilerInstance,
	})
end

ContextActionService:BindAction(OPEN_ACTION, function(_, InputState)
	if Starting
		or InputState ~= Enum.UserInputState.Begin
		or not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
	then
		return Enum.ContextActionResult.Pass
	end

	Starting = true
	ContextActionService:UnbindAction(OPEN_ACTION)
	task.defer(Start)
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.F5)
