local Settings = settings()

local Plugin = script:FindFirstAncestorOfClass("Plugin")
local Packages = Plugin.PacketProfiler.Packages

local Roact = require(Packages.Roact)

local StudioThemeProvider = Roact.Component:extend("StudioThemeProvider")
local StudioSettings = Settings.Studio

function StudioThemeProvider:init()
	self:setState({
		CurrentTheme = StudioSettings.Theme
	})
	self.StudioThemeChanged = StudioSettings.ThemeChanged:Connect(function()
		self:setState({
			CurrentTheme = StudioSettings.Theme
		})
	end)
end

function StudioThemeProvider:render()
	local Component = Roact.oneChild(self.props[Roact.Children])
	return Component(self.state.CurrentTheme)
end

function StudioThemeProvider:willUnmount()
	self.StudioThemeChanged:Disconnect()
end

local function StudioTheme(Component)
	return Roact.createElement(StudioThemeProvider, {}, {
		Component = Component,
	})
end

return StudioTheme