local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local PacketChart = require(PacketProfiler.Components.PacketChart)
local PacketProfilerView = require(PacketProfiler.Components.PacketProfiler)
local StudioTheme = require(PacketProfiler.Components.StudioTheme)
local UIState = require(PacketProfiler.Modules.UIState)

local function MainPlugin(props)
	return Vide.mount(function()
		local theme = StudioTheme()
		local state = UIState(props)
		Vide.effect(function()
			if state.ProfilerEnabled() then
				Vide.cleanup(Vide.mount(function()
					PacketProfilerView({ State = state, Theme = theme })
				end))
			end
		end)
		local chartView = PacketChart({
			Plugin = props.Plugin,
			State = state,
			Theme = theme,
		})

		Vide.cleanup(chartView)
	end)
end

return MainPlugin
