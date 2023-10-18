# Real War (2001) Decompilation
![](./docs/shields/total.svg) ![](./docs/shields/funcs.svg)

A work in progress decompilation of the PC game [Real War (2001) by Rival Interactive](https://en.wikipedia.org/wiki/Real_War_(video_game)).

## Prerequisites
> **Note:** This decomp assumes you are running on Windows, but theoretically it could be tweaked to run on Linux/macOS.

- A legitimate copy of the game (CD version "9.25").
- Visual C++ 6.0 Professional/Enterprise (build 8168)
    - Tooling currently assumes that this is installed at the default location:
        - `C:\Program Files (x86)\Microsoft Visual Studio\VC98`
        - `C:\Program Files (x86)\Microsoft Visual Studio\Common\MSDev98`
    - This can also be installed via Visual Studio 6.0 Enterprise (6.00.8168).
- DirectX 7 SDK
    - The game's readme claims that it needs DX8, however the game code does not use the DX8 style of programming and instead appears to be based on DX6 with some usage of DX7 APIs. More research is needed here.
- [Dart](https://dart.dev/) >=3.1.0
- [Ninja](https://ninja-build.org/)
- [Just](https://just.systems/)

## Development

### Setup
1. Install game.
    - Typical install directory: `C:\Program Files (x86)\Simon and Schuster\Real War`.
2. Copy game files into `game/`.
    - `game` should directly contain `data`, `vids`, and `RealWar.exe`.
    - `data/bigfile.dat` should also be present and not the `.cab` files from the CD.
3. Build [Capstone](https://www.capstone-engine.org/) (v4) and place `capstone.dll` in `tools/`.
4. Build tools: `just build-tools`
5. Verify game exe: `just verifybase`
6. Extract asm/bin: `just split`
7. Configure build script: `just configure`
8. Build: `just build`
9. Verify recompiled exe: `just verify`

### Decompiling
A quick overview of the decompilation process:

- Decompile functions and place them in `rw/src`.
- Map files in `rw/src` and symbols to virtual exe addresses in `rw.yaml`.
- For functions that haven't been decompiled yet but are in the middle of a source file, add a `#pragma ASM_FUNC function_name` line in its place (with `function_name` being the actual name of the function) to let the rest of the file compile correctly.
    - If the function is not void, add `hasret` after the function name.
- If segments in `rw.yaml` are updated or new `#pragma ASM_FUNC`s are added, re-run `just split`.
- If source files are added/renamed/deleted, re-run `just configure`.
- Use `just diff {function name}` for live function diffing.
- Once the function matches: rebuild and verify (shortcut: `just check`).
- If the function doesn't match, surround it with `#ifdef NON_MATCHING` and add back its `#pragma ASM_FUNC`
    - If the function isn't even logically the same yet, surround it with `#ifdef NON_EQUIVALENT` instead.

## Cool Stuff

### Tools
- `tools/rw_assets/bin/bigfile.dart` - Unpacks all files in `bigfile.dat` into a directory. 
- `tools/rw_assets/bin/tgc.dart` - Converts to and from Real War's Targa Compressed (TGC) image files. 

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