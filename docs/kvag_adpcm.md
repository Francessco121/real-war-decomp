Real War stores audio files in the ADPCM format usually in the KVAG container.

These are `.VAG` files on disk.

KVAG Format:
| Offset | Size | Desc |
|--------|------|------|
| 0x0    | 4    | The string "KVAG" |
| 0x4    | 4    | Size of ADPCM data in file (in bytes) |
| 0x8    | 4    | Sample rate |
| 0xC    | 2    | 0 (Mono) or 1 (Stereo) |
| 0xE    | ADPCM data size | ADPCM bytes |

The original game function for reading these files can be found at RAM `0x004d25e0`.

Fun fact: FFMPEG can read/write these files as of this patch: https://ffmpeg.org/pipermail/ffmpeg-devel/2020-February/256626.html
