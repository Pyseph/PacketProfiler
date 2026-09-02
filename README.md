
<h1 align="center">
PacketProfiler

<img src="https://user-images.githubusercontent.com/45090858/181864347-96269b03-25d7-475a-a7ad-352e1955fd4f.png" width="100" height="100" /></h1>

<div align="center">Extensible replication profiler for Roblox</div>

<div>&nbsp;</div>

## Introduction

Packet Profiler shows the volume and contents of replication traffic frame by frame. Remote traffic is included out of the box, while a public layer API lets each game add its own sources, such as instance replication, custom networking libraries, state synchronization, or domain-specific metrics.

Remote buffer sizes account for Roblox's transparent Zstandard compression. Compressed values are labeled as estimates alongside their uncompressed serialized size because Roblox does not expose exact per-remote transport framing.

When addons register more traffic sources, the timeline can show all layers together or isolate any individual layer without discarding the combined capture. The view selector stays hidden when remotes are the only registered layer. Selecting a frame opens a breakdown of the calls recorded for the active view.

The **Top spikes** view retains the largest frames from the full profiler session, even after they leave the rolling timeline. It can show the top 5, 10, or 20 frames for the combined view or any registered layer. The details widget becomes a largest-first spike inspector with comparable magnitude bars, contributor summaries, expandable packet data, bulk expand/collapse, and a frozen ranking mode for reading while capture continues.

The rolling timeline uses timestamped 60 Hz buckets, so its 256 bars consistently cover about 4.27 seconds. When rendering slows down, the capture clock commits every elapsed bucket instead of collapsing them into one rendered frame. Extensions can read the bucket duration with `GetFrameInterval()`.

The interface is rendered with Vide. The timeline is a mirrored cyclic strip: each commit writes one persistent bar slot and shifts the strip, so existing heights remain untouched until their frames genuinely leave the 256-frame window. This avoids full-chart reconciliation and render-frame polling.

![image](https://github.com/Pyseph/PacketProfiler/assets/45090858/9a68dc84-0ad5-4358-9e79-8750d9e40b2e)
![image](https://user-images.githubusercontent.com/45090858/181864397-9b9d5e82-72fe-4bee-b29f-9b8e5a16aa4d.png)

## Adding Remote Functions
Since Remote Functions only allow setting one write-only callback, you can manually tell the profiler to log packets by adding a BindableEvent anywhere in ReplicatedStorage called `RemoteFunctionEvent.profiler`. You can then fire this BindableEvent with a RemoteFunction as the first argument, and any data as the rest of the arguments. The profiler will then log the packet data.

This BindableEvent may also be used to log RemoteEvents that have been created at run-time.

## Renaming RemoteEvents
Some games may rename their RemoteEvents for network & encoding purposes (such as those that only use 1 RemoteEvent for everything). You can rename RemoteEvents by adding a `RemoteName.profiler` ModuleScript anywhere in ReplicatedStorage, whose return must be a function. This function will be called with two arguments: the invoked RemoteEvent, and the RemoteEvent's first argument. The function must return a string, which will be used as the RemoteEvent's name in the profiler.
**NOTE**: adding this will cause the profiler to use the module to rename all remote events, so make sure to return the original name if you don't want to rename a specific RemoteEvent.

## Extension API

Requiring the in-game package returns the running profiler. In a Studio client with the PacketProfiler plugin installed, it instead returns a bridge to the plugin so game-defined layers appear in the plugin window rather than opening a second profiler UI. The installed plugin connects its Edit and Play client instances through `PluginConnectionService`; no server relay or script-injection permission is required.

Layers describe a source of traffic and receive an `Emit` function. The value returned by `Start` is used as the layer's cleanup function.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PacketProfiler = require(ReplicatedStorage.Packages.PacketProfiler)

local registration = PacketProfiler:RegisterLayer({
	Id = "instance-audit",
	Name = "Instance audit",
	Color = Color3.fromHex("#B98CFF"),
	Description = "Replicated instance creation",

	Start = function(context)
		local connection = workspace.DescendantAdded:Connect(function(instance)
			context.Emit({
				Name = instance.ClassName,
				Size = 24,
				Data = {
					Path = instance:GetFullName(),
					ClassName = instance.ClassName,
				},
				Metadata = {
					Instance = instance,
				},
			})
		end)

		return function()
			connection:Disconnect()
		end
	end,
})

-- Remove the layer and stop its capture adapter later.
registration:Disconnect()
```

Every packet needs a display `Name` and non-negative byte `Size`. `Data`, `RawData`, `Metadata`, and `Timestamp` are optional. Metadata is deliberately layer-defined so addons can retain references or structured context without changing the profiler core.

Studio-bridged descriptors and packets are serialized across a `PluginConnection`, so keep their fields to primitives, tables, Roblox vectors and colors, enum items, and Instances. Functions remain client-side in `Start` and are never sent to the plugin. Set `IncludeInAll = false` for a count-based or non-byte layer that should have its own view without changing the combined byte graph. `EntryName`, `Unit`, `DefaultMaxFrameValue`, and `ScaleValues` customize that view's labels and scale.

### Hooks and addons

Hooks can observe or transform traffic without owning a layer:

```luau
local hook = PacketProfiler:RegisterHook("BeforeRecord", function(packet)
	if packet.Metadata and packet.Metadata.IgnoreInProfiler then
		return false
	end

	return packet
end)
```

Supported stages are `BeforeRecord`, `AfterRecord`, and `FrameCommitted`. Returning `false` from `BeforeRecord` drops a packet; returning a table replaces it. Addons can group several layers and hooks behind one lifecycle:

```luau
local addon = PacketProfiler:RegisterAddon({
	Id = "my-network-suite",
	Install = function(profiler)
		local layer = profiler:RegisterLayer(MyLayer)
		local hook = profiler:RegisterHook("AfterRecord", MyObserver)

		return function()
			layer:Disconnect()
			hook:Disconnect()
		end
	end,
})
```

The Studio bridge exposes `RegisterLayer`, `RegisterHook`, `Record`, `RegisterAddon`, and `Destroy`. Its `BeforeRecord` and `AfterRecord` hooks run in the game client before packets are batched to the plugin. The full in-game profiler additionally exposes `SetView`, `SetPaused`, `SelectFrame`, `GetLayer`, `GetLayers`, `GetFramePackets`, `GetTopFrames`, frame hooks, and UI signals; view and frame state remain owned by the plugin. `GetTopFrames(view, limit)` returns ranked `{ Frame, Size }` entries retained from the current session.

## In-game profiling
Sometimes, simply profiling in studio may not be enough. As such, you can use this plugin **in-game**! Simply grab the latest release `.rbxm` file and place it inside `StarterPlayerScripts`. The profiler initializes lazily the first time you press `Ctrl + F5`, so it does not scan remotes or run a frame loop before it is opened. After that, use `Ctrl + F5` to toggle the UI and `Ctrl + P` to pause or unpause capture.
<https://github.com/Pyseph/PacketProfiler/releases/>

Alternatively, you can install the in-game profiler through **Wally**:
<https://wally.run/package/pysephwasntavailable/packetprofiler>

# Installation

### Method 1: Studio Plugin (Roblox Studio)
- Install the PacketProfiler Roblox Studio plugin from the [Roblox Studio Plugin page](https://www.roblox.com/library/10332340067/PacketProfiler).
### Method 2: Model file (In-game profiler)
- Download the `rbxm` model file attached to the latest release from the [Releases page](https://github.com/Pyseph/PacketProfiler/releases).
### Method 3: Wally (In-game profiler)
- Add `pysephwasntavailable/packetprofiler@version` to your `wally.toml` file, or grab the command from the [wally.run page](https://wally.run/package/pysephwasntavailable/packetprofiler).
