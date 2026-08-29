local PacketProfiler = script.Parent.Parent
local Packages = require(PacketProfiler.Modules.Packages)
local Vide = require(Packages.Directory.Vide)

local StudioSettings = require(PacketProfiler.Components.StudioSettings)
local Cleanup = require(PacketProfiler.Modules.Cleanup)

local function StudioTheme()
	local revision = Vide.source(0)

	Vide.cleanup(Cleanup.disconnect(StudioSettings.ThemeChanged:Connect(function()
		revision(revision() + 1)
	end)))

	return function(name)
		revision()
		return StudioSettings.Theme:GetColor(name)
	end
end

return StudioTheme
