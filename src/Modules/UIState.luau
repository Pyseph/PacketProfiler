local UserInputService = game:GetService("UserInputService")

local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local BYTE_SCALES = { 1_000, 10_000, 50_000, 100_000 }
local SCALE_SETTINGS_KEY = "PacketProfilerViewScales"
local TOP_COUNT_SETTINGS_KEY = "PacketProfilerTopSpikeCount"
local TOP_COUNTS = { 5, 10, 20 }

local cleanup = Vide.cleanup
local effect = Vide.effect
local source = Vide.source

local function getViewScaleConfig(profiler, view)
	local layer = view ~= "all" and profiler:GetLayer(view) or nil
	return layer and layer.ScaleValues or BYTE_SCALES, layer and layer.DefaultMaxFrameValue or 10_000
end

local function getScale(viewScales, view, scales, defaultScale)
	local savedScale = viewScales[view]
	return if table.find(scales, savedScale) then savedScale else defaultScale
end

local function loadViewScales(plugin)
	if plugin == nil then
		return {}
	end
	local saved = plugin:GetSetting(SCALE_SETTINGS_KEY)
	if type(saved) ~= "table" then
		return {}
	end

	local viewScales = {}
	for view, scale in saved do
		if type(view) == "string" and type(scale) == "number" and scale > 0 then
			viewScales[view] = scale
		end
	end
	return viewScales
end

local function loadTopCount(plugin)
	if plugin then
		local saved = plugin:GetSetting(TOP_COUNT_SETTINGS_KEY)
		if table.find(TOP_COUNTS, saved) then
			return saved
		end
	end
	return 10
end

local function UIState(props)
	local plugin = props.Plugin
	local profiler = props.Profiler
	local viewScales = loadViewScales(plugin)
	local initialScales, initialDefault = getViewScaleConfig(profiler, profiler.View)

	local state = {
		ProfilerEnabled = source(plugin and plugin:GetSetting("PacketProfilerEnabled") == true or false),
		ChartEnabled = source(plugin and plugin:GetSetting("PacketChartEnabled") == true or false),
		Mode = source("timeline"),
		TopCount = source(loadTopCount(plugin)),
		Layers = source(profiler:GetLayers()),
		View = source(profiler.View),
		Paused = source(profiler.Paused),
		MaxFrameSize = source(getScale(viewScales, profiler.View, initialScales, initialDefault)),
		Profiler = profiler,
	}

	function state.GetActiveLayer()
		local view = state.View()
		return view ~= "all" and profiler:GetLayer(view) or nil
	end

	function state.ActiveColor()
		local layer = state.GetActiveLayer()
		return layer and layer.Color or Color3.fromHex("#4CC2FF")
	end

	function state.EntryName()
		local layer = state.GetActiveLayer()
		return layer and layer.EntryName or "packets"
	end

	function state.Unit()
		local layer = state.GetActiveLayer()
		return layer and layer.Unit or "bytes"
	end

	function state.Scales()
		local layer = state.GetActiveLayer()
		return layer and layer.ScaleValues or BYTE_SCALES
	end

	function state.AllViewName()
		state.Layers()
		return profiler:GetAllViewName()
	end

	function state.SetProfilerEnabled(enabled)
		state.ProfilerEnabled(enabled)
		if props.PacketProfilerButton then
			props.PacketProfilerButton:SetActive(enabled)
		end
		if plugin then
			plugin:SetSetting("PacketProfilerEnabled", enabled)
		end
	end

	function state.SetChartEnabled(enabled)
		state.ChartEnabled(enabled)
		if props.PacketChartButton then
			props.PacketChartButton:SetActive(enabled)
		end
		if plugin then
			plugin:SetSetting("PacketChartEnabled", enabled)
		end
	end

	function state.SetMode(mode)
		state.Mode(mode)
		if mode == "spikes" then
			state.SetChartEnabled(true)
		end
	end

	function state.CycleTopCount()
		local index = table.find(TOP_COUNTS, state.TopCount()) or 1
		local value = TOP_COUNTS[index % #TOP_COUNTS + 1]
		state.TopCount(value)
		if plugin then
			plugin:SetSetting(TOP_COUNT_SETTINGS_KEY, value)
		end
	end

	function state.CycleScale()
		local scales = state.Scales()
		local index = table.find(scales, state.MaxFrameSize()) or 1
		local value = scales[index % #scales + 1]
		local view = state.View()
		viewScales[view] = value
		state.MaxFrameSize(value)
		if plugin then
			plugin:SetSetting(SCALE_SETTINGS_KEY, table.clone(viewScales))
		end
	end

	if props.PacketProfilerButton then
		props.PacketProfilerButton:SetActive(state.ProfilerEnabled())
		cleanup(props.PacketProfilerButton.Click:Connect(function()
			state.SetProfilerEnabled(not state.ProfilerEnabled())
		end))
	end
	if props.PacketChartButton then
		props.PacketChartButton:SetActive(state.ChartEnabled())
		cleanup(props.PacketChartButton.Click:Connect(function()
			state.SetChartEnabled(not state.ChartEnabled())
		end))
	end

	if not Packages.IsPlugin then
		cleanup(UserInputService.InputBegan:Connect(function(input, processed)
			if processed or not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				return
			end
			if input.KeyCode == Enum.KeyCode.F5 then
				state.SetProfilerEnabled(not state.ProfilerEnabled())
			elseif input.KeyCode == Enum.KeyCode.P then
				profiler:SetPaused(not profiler.Paused)
			end
		end))
	end

	cleanup(Cleanup.disconnect(profiler.LayersChanged:Connect(function(layers)
		state.Layers(layers)
	end)))
	cleanup(Cleanup.disconnect(profiler.PauseChanged:Connect(function(paused)
		state.Paused(paused)
	end)))
	cleanup(Cleanup.disconnect(profiler.ViewChanged:Connect(function(view)
		local scales, defaultScale = getViewScaleConfig(profiler, view)
		state.View(view)
		state.MaxFrameSize(getScale(viewScales, view, scales, defaultScale))
	end)))
	cleanup(Cleanup.disconnect(profiler.SelectionChanged:Connect(function(frame)
		local hasPackets = frame ~= nil and frame.PacketCount > 0
		if hasPackets or not Packages.IsPlugin then
			state.SetChartEnabled(hasPackets)
		end
	end)))

	effect(function()
		if props.PacketProfilerButton then
			props.PacketProfilerButton:SetActive(state.ProfilerEnabled())
		end
		if props.PacketChartButton then
			props.PacketChartButton:SetActive(state.ChartEnabled())
		end
	end)

	return state
end

return UIState
