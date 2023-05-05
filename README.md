
<h1 align="center">
PacketProfiler

<img src="https://user-images.githubusercontent.com/45090858/181864347-96269b03-25d7-475a-a7ad-352e1955fd4f.png" width="100" height="100" /></h1>

<div align="center">Remote packet analyzer tool for Roblox</div>

<div>&nbsp;</div>

## Introduction

Packet Profiler is a plugin which allows you to accurately read remote data sent by different contexts. Unlike the vague and uninformative Stats windows which only show the current KB/s receive and send rates, this plugin allows you to accurately see packet data each frame, along with precise byte size information.
![image](https://user-images.githubusercontent.com/45090858/181864397-9b9d5e82-72fe-4bee-b29f-9b8e5a16aa4d.png)
![image](https://user-images.githubusercontent.com/45090858/181864404-9a0bdcb9-f89e-4c21-bdc7-201a88cb36f7.png)

## Adding Remote Functions
Since Remote Functions only allow setting one write-only callback, you can manually tell the profiler to log packets by adding a BindableEvent anywhere in ReplicatedStorage called `RemoteFunctionEvent.profiler`. You can then fire this BindableEvent with a RemoteFunction as the first argument, and any data as the rest of the arguments. The profiler will then log the packet data.

This BindableEvent may also be used to log RemoteEvents that have been created at run-time.

## Renaming RemoteEvents
Some games may rename their RemoteEvents for network & encoding purposes (such as those that only use 1 RemoteEvent for everything). You can rename RemoteEvents by adding a `RemoteName.profiler` ModuleScript anywhere in ReplicatedStorage, whose return must be a function. This function will be called with two arguments: the invoked RemoteEvent, and the RemoteEvent's first argument. The function must return a string, which will be used as the RemoteEvent's name in the profiler.
**NOTE**: adding this will cause the profiler to use the module to rename all remote events, so make sure to return the original name if you don't want to rename a specific RemoteEvent.

# Installation

### Method 1: Studio Plugin (Roblox Studio)
- Install the PacketProfiler Roblox Studio plugin from the [Roblox Studio Plugin page](https://www.roblox.com/library/10332340067/PacketProfiler).
### Method 2: Model file (In-game profiler)
- Download the `rbxm` model file attached to the latest release from the [Releases page](https://github.com/PysephWasntAvailable/PacketProfiler/releases).
### Method 3: Wally (In-game profiler)
- Add `pysephwasntavailable/packetprofiler@version` to your `wally.toml` file, or grab the command from the [wally.run page](https://wally.run/package/pysephwasntavailable/packetprofiler).
