# Real War (2001) Decompilation
A work in progress decompilation of the PC game [Real War (2001) by Rival Interactive](https://en.wikipedia.org/wiki/Real_War_(video_game)).

## Prerequisites
> **Note:** This decomp assumes you are running on Windows, but theoretically it could be tweaked to run on Linux/macOS.

- A legitimate copy of the game.
- Visual C++ 6.0 Professional/Enterprise (build 8168)
    - Tooling currently assumes that this is installed at the default location:
        - `C:\Program Files (x86)\Microsoft Visual Studio\VC98`
        - `C:\Program Files (x86)\Microsoft Visual Studio\Common\MSDev98`
    - This can also be installed via Visual Studio 6.0 Enterprise (6.00.8168).
- DirectX 5,6,7,8 SDK (still figuring out exactly which one to use)
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
- If segments in `rw.yaml` are updated or new `#pragma ASM_FUNC`s are added, re-run `just split`.
- If source files are added/renamed/deleted, re-run `just configure`.
- Use `just diff {function name}` for live function diffing.
- Once the function matches: rebuild and verify (shortcut: `just check`).
- If the function doesn't match, surround it with `#if NON_MATCHING` and add back its `#pragma ASM_FUNC`

## Cool Stuff
- `tools/extract_bigfile.dart` - Unpacks all files in `bigfile.dat` into a directory. 
