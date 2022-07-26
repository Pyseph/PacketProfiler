local PacketProfiler = script:FindFirstAncestor("PacketProfiler")
local Packages = PacketProfiler.Packages
local Components = PacketProfiler.Components

local Roact = require(Packages.Roact)
local StudioSettings = require(Components.StudioSettings)

local StudioThemeProvider = Roact.Component:extend("StudioThemeProvider")

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