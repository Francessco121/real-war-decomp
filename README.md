# Real War (2001) Decompilation
A work in progress decompilation of the PC game [Real War (2001) by Rival Interactive](https://en.wikipedia.org/wiki/Real_War_(video_game)).

## Prerequisites
- A legitimate copy of the game.
- Visual C++ 6.0 Professional/Enterprise (build 8168)
    - Tooling currently assumes that this is installed at the default location:
        - `C:\Program Files (x86)\Microsoft Visual Studio\VC98`
        - `C:\Program Files (x86)\Microsoft Visual Studio\Common\MSDev98`
    - This can also be installed via Visual Studio 6.0 Enterprise (6.00.8168).
- DirectX 5,6,7,8 SDK (still figuring out exactly which one to use)
- Dart >=2.19.0

## Development
1. Install game.
    - Typical install directory: `C:\Program Files (x86)\Simon and Schuster\Real War`.
2. Copy game files into `game/`.
    - `game` should directly contain `data`, `vids`, and `RealWar.exe`.
    - `data/bigfile.dat` should also be present and not the `.cab` files from the CD.
2. TODO
