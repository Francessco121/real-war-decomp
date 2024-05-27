# Real War (2001) Decompilation
![](./docs/shields/coverage.svg) ![](./docs/shields/accuracy.svg)

A work in progress decompilation of the PC game [Real War (2001) by Rival Interactive](https://en.wikipedia.org/wiki/Real_War_(video_game)).

## Prerequisites
> **Note:** This decomp assumes you are running on Windows, but theoretically it could be tweaked to run on Linux/macOS.

- A legitimate copy of the game (CD version "9.25").
- Visual C++ 6.0 Professional/Enterprise (build 8168)
    - Tooling currently assumes that this is installed at the default location:
        - `C:\Program Files (x86)\Microsoft Visual Studio\VC98`
        - `C:\Program Files (x86)\Microsoft Visual Studio\Common\MSDev98`
    - This can also be installed via Visual Studio 6.0 Enterprise (6.00.8168).
- DirectX 8 SDK
    - Tooling currently assumes that this is installed at `C:\dx8sdk`
- [Dart](https://dart.dev/) >=3.3.0
- [Ninja](https://ninja-build.org/)
- [Just](https://just.systems/)

## Development

### Setup
1. Install game.
    - Typical install directory: `C:\Program Files (x86)\Simon and Schuster\Real War`.
2. Copy game files into `game/`.
    - `game` should directly contain `data`, `vids`, and `RealWar.exe`.
    - `data/bigfile.dat` should also be present and not the `.cab` files from the CD.
3. Build [Capstone](https://www.capstone-engine.org/) (v5.0) and place `capstone.dll` in `tools/`.
4. Build tools: `just build-tools`
5. Verify game exe: `just verifybase`
6. Configure build script: `just configure`
7. Build: `just build`
8. Verify recompiled exe: `just verify`

### Decompiling
A quick overview of the decompilation process:

- Decompile functions and place them in `rw/src`.
- Map files in `rw/src` and symbols to virtual exe addresses in `rw.yaml`.
- If source files are added/renamed/deleted, re-run `just configure`.
- Use `just diff {function name}` for live function diffing.
- Once the function matches or is logically equivalent: build and verify (shortcut: `just check`).
- If the function isn't logically equivalent but worth committing, surround it with `#ifdef NON_EQUIVALENT`.

## Cool Stuff

### Compatibility Fixes
Real War has various issues running on modern Windows. Eventually, this project aims to provide patches but for now external software can be used to run the game quite well.

#### DDrawCompat
See [docs/ddraw_compat.md](./docs/ddraw_compat.md) for a guide for using DDrawCompat to fix most of the game's issues.

#### Wine
[Wine](https://www.winehq.org/) on Linux runs Real War very well out of the box, with basically perfect hardware acceleration. Still needs a framerate limiter. Try out the virtual desktop option for a hardware acceleration compatible windowed mode!

### Asset Viewer
Explore Real War's custom asset files with a viewer program built upon knowledge from this decompilation project: https://github.com/Francessco121/real-war-asset-viewer

### Tools
- `tools/rw_assets/bin`
    - `bigfile.dart` - Unpacks all files in `bigfile.dat` into a directory. 
    - `bse.dart` - Exports Real War's BSE model files. 
    - `kvag.dart` - Converts to and from Real War's KVAG audio files. 
    - `spt.dart` - Exports Real War's SPT 2D sprite/animation files.
    - `tgc.dart` - Converts to and from Real War's Targa Compressed (TGC) image files. 

### Game CLI Args
The game has many undocumented command-line arguments that it will accept. Each argument starts with a `-`, followed by a single uppercase letter. For an argument to actually be recognized by the game, it must have a "value" after it (i.e. `-G 1`) even if the "value" has no effect (i.e. it can be anything, it just needs to be there). Note: There does not need to be a space between the argument name and its value.
- `-G 1` - Launch in windowed mode.
    - Doesn't seem to work with hardware-acceleration enabled (with the exception of the editor/model viewer, which work fine).
- `-L 1` - Launch the "model viewer" instead of the game.
    - It seems this can do a little more than just view models. Pressing <kdb>s</kdb> will prompt to save the file in the BSE format.
- `-E 1` - Launch "editor 1" instead of the game.
    - The file `data\editor\menu.tgc` must be created or else this will crash (ideally this should be an 800x600 image, for example you can use `data\idc\tgas\BACKbl.tgc` (the main menu background)).
- `-E 2` - Launch "editor 2" instead of the game.
    - **NOT RECOMMENDED**: This editor will give you a few hundred error dialog boxes and then crash. Needs to be patched.
- `-H 1` - Launch the game with hardware acceleration enabled.
- `-T 1` - Launch the game with bunch of debug information displayed.
- `-M <mission number>` - Launch the game directly into any mission.
    - Note: The mission number is 1-base indexed, so if you want to load `miss02` you need to pass `-M 3`.
- `-R<folder path>` - Sets registry keys under `HKEY_CURRENT_USER\SOFTWARE\Classes\VirtualStore\MACHINE\SOFTWARE\WOW6432Node\RealWar` which will override the registry keys normally set by the installer at `HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\REALWAR`.
    - These keys tell the game where it's installed, although it only uses this to load some assets.
    - Example: `-RC:\RealWar\` will make the game think it's installed at `C:\RealWar`.
    - Don't forget a slash at the end of the path!
    - It doesn't seem like it's possible to pass a path that has spaces in it.
    - If you break your game with this, just simply delete the keys.
- `-S 1` - Launches the game into a new multiplayer lobby.
- `-C 1` - Unknown.
- `-B 1` - Unknown.
- `-N<string>` - Unknown.
- `-P<string>` - Unknown.
- `-F 1` - Recognized by the game, but does nothing.