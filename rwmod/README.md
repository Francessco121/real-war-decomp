# rwmod
A project for modding Real War.

Mainly used to assist in the decomp and debug the game, although it can be used for all kinds of shenanigans.

## Setup

### Game Files
To avoid messing up a vanilla install, copy all of the game files into the `game` directory. The `justfile` provided assumes that the game is copied there and the mod tools will overwrite `RealWar.exe`, so keep a backup!

### Registry Keys
Real War uses Windows registry keys to store paths to the data directory. If you want to mod anything in `bigfile.dat` in particular, you need to either update the copy of that file in the game's default installation directory or change the registry keys to point to the game folder in this directory (preferred). Be sure to backup the old registry keys!

The registry keys can be found (on Windows 10) at `HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\REALWAR`.
> **IMPORTANT:** Make sure the paths end in a slash or else the game will fail to load!

## Building
1. Run `just extract`.
    - Only required if cloned function definitions in `rwmod.yaml` were changed.
2. Run `just configure`.
    - Only required if cloned function definitions in `rwmod.yaml` were changed or if source files were added/renamed/deleted.
3. Run `just build`.

Check out the `justfile` for shortcuts.

## Modding Game Code
Custom code can be appended to the game executable and functions in the base game code can be replaced (or extended!) with custom "hook" functions.

Hook functions can be defined in `rwmod.yaml` and map a function from the base game to a custom function you write. The `rwpatch` tool will replace the game's base function with a single instruction to jump to your hook function.

Creating hooks makes it impossible to call back into the base function. If your hook does not re-implement the function and you would like to call back into the original, you can define a "cloned" function in `rwmod.yaml`. This will tell the `extract` and `rwpatch` tools that the raw machine code for a base game function should be copied out of the game and re-linked in for use by your custom code. The tooling will take care of relocating instructions for you, however you must give the cloned function a different symbol than the original function since the the original symbol still points to the base code with the patched-in jump instruction.

Any functions/globals that have symbols listed in `rw.yaml` can be used by custom code. Functions just need a prototype defined (use the headers from the decomp or write your own). Globals work similarly but they must be marked as `extern` (so using existing headers may not always be possible).

## Modding Game Assets
Files can simply be swapped out in the `data` and `vids` directory for many assets.

For files that are in `bigfile.dat` you will need to unpack the files first, edit them, and then repack the files into a new `bigfile.dat`. To unpack, run `just unpack-bigfile`. This will unpack all files into `game/bigfile`. After modifying files, run `just repack-bigfile` to repack these files into `game/data/bigfile.dat`.

## Working With Real War's Asset Files

### Audio (.VAG files)
Real War uses KVAG files (a custom format) for audio. This format is essentially just raw ADPCM data with a small header prepended. Luckily, `ffmpeg` has support for these files!

- Convert VAG to WAV: `ffmpeg -i <input>.VAG -acodec pcm_s16le <output>.wav`
    - Using WAV with `pcm_s16le` avoids losing quality from re-encoding for the most part since that's more-or-less the format VAG is already in.
- Convert any audio to VAG: `ffmpeg -i <input>.<ext> <output>.VAG`
    - The only codec for this is `adpcm_ima_ssi` so no options are really needed.

> Note: You can use `ffplay` to test any file conversions. `ffplay` can play `.VAG` files directly.
