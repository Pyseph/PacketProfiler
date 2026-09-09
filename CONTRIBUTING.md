# Contributing

## Code
This resource uses Aftman to manage the tools used for this project. You may find Aftman here:
- https://github.com/LPGhatguy/aftman
After installation, the tools can be installed by running `aftman install` in the root directory of this project.

Additionally, Rojo is used to sync the code to Roblox Studio. You may find Rojo here:
- https://rojo.space/

There exist different `project.json` files for different purposes:
- `buildplugin.project.json` builds the plugin rbxm file for Roblox Studio
- `buildrelease.project.json` builds the release rbxm file for in-game use
- `packagedev.project.json` syncs the code to Roblox Studio for in-game package development
- `plugindev.project.json` attempts to sync the code to Roblox Studio for plugin development, but is currently not fully functional

## Bug Reports & Feature Requests
Please use the [issue tracker](https://github.com/Pyseph/PacketProfiler/issues) to report any bugs or file feature requests.

## Developing

Run `lune run tests/performance.luau` with Lune 0.10.4 to check capture lifecycle, bounded discovery, remote subscription cleanup, and Studio bridge demand. These tests load the source modules with mocked engine signals and instance trees; verify UI behavior and frame times separately in Studio. Run `selene src build` and build both `buildplugin.project.json` and `buildrelease.project.json` with Rojo before release.
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## Adding a new data type
The packet size counter is a separate GitHub repository that is used as a submodule for this project. You can find it here:
https://github.com/PysephWasntAvailable/RemotePacketSizeCounter

## License
[MIT](https://choosealicense.com/licenses/mit/)

## Contact
- Discord: Pyseph#0001
- Roblox Developer Forum: https://devforum.roblox.com/u/pysephdev/summary
