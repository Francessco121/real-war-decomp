# Targa Compressed (TGC)
Real War uses a custom file format with the extension `.tgc`, which contains run-length encoded ARGB1555 pixel data. The game code references most texture files with a `.tga` (Targa) extension, however the functions reponsible for actually loading the file instead modify the given file path to look for a `.tgc` file instead. It appears that during development the developers worked primarily with Targa image files but converted them to this custom compressed format for release.

The name "Targa Compressed" is just a guess. No where in the game does it actually refer to these file types by a name.

## File Format
All numerics are little-endian and unsigned.

| Offset    | Length    | Field        | Description             |
|-----------|-----------|--------------|-------------------------|
| 0x0       | 2         | width        | Image pixel width       |
| 0x2       | 2         | height       | Image pixel height      |
| 0x4       | variable  | rleBytes     | Run-length encoded pixel data |
| 0x4 + len(rleBytes) | 4 | rleEndMarker | The dword 0xFFFFFFFF  |
| 0x8 + len(rleBytes) | 4 | trailer    | A 32-bit trailer with an unknown purpose |

The byte size of the unencoded image data can be determine by: `width * height * 2`.

It is not currently known what the last 32-bits are for. Many files have this set to zero. The game itself does not appear to do anything with the trailer and runs just fine even if omitted entirely.

### Run-length Encoding
The `rleBytes` portion of the file is made up of a list of runs. Each run starts with a 16-bit "control" word that defines the type and length of the run. The end of the encoded image data is marked by the 32-bit dword `0xFFFFFFFF`.

The control word can be decoded as follows: the highest-bit determines whether the run contains literal pixel data (MSB = 1) or if it instead denotes a single pixel to be repeated (MSB = 0). The remaining 15-bits specify the length (in pixels) of the run. The maximum length of a run is 32,767 however in practice the TGC files that the game ships with break up runs after 4,096 elements.

Literal run:
| Offset    | Length    | Field        | Description             |
|-----------|-----------|--------------|-------------------------|
| 0x0       | 2         | ctrl         | The control word (MSB = 1) |
| 0x2       | (ctrl & 0x7FFF) * 2 | literalPixels | Unencoded pixels (16-bit each) |

Repeat run:
| Offset    | Length    | Field        | Description             |
|-----------|-----------|--------------|-------------------------|
| 0x0       | 2         | ctrl         | The control word (MSB = 0) |
| 0x2       | 2         | repeatPixel  | The pixel to repeat (ctrl & 0x7FFF) times |
