local PacketProfiler = script.Parent.Parent

local ProfilerPackages = PacketProfiler:FindFirstChild("Packages")
return {
	Directory = ProfilerPackages or PacketProfiler.Parent,
	IsPlugin = ProfilerPackages ~= nil
}