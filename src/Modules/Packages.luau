local PacketProfiler = script.Parent.Parent

local ProfilerPackages = PacketProfiler:FindFirstChild("Packages")
local PackageDirectory = ProfilerPackages or PacketProfiler.Parent

local function resolvePackage(Alias: string, PackageName: string): ModuleScript
	local PackageIndex = PackageDirectory:FindFirstChild("_Index")

	if PackageIndex then
		for _, VersionDirectory in PackageIndex:GetChildren() do
			local Package = VersionDirectory:FindFirstChild(PackageName)

			if Package then
				if Package:IsA("ModuleScript") then
					return Package
				end

				local Source = Package:FindFirstChild("src")

				if Source and Source:IsA("ModuleScript") then
					return Source
				end
			end
		end
	end

	local PackageAlias = PackageDirectory:FindFirstChild(Alias)
	assert(PackageAlias and PackageAlias:IsA("ModuleScript"), `Missing package {Alias}`)

	return PackageAlias
end

local Directory = {
	PacketSizeCounter = resolvePackage("PacketSizeCounter", "remotepacketsizecounter"),
	Signal = resolvePackage("Signal", "goodsignal"),
	Vide = resolvePackage("Vide", "vide"),
}

return {
	Directory = Directory,
	IsPlugin = ProfilerPackages ~= nil,
}
