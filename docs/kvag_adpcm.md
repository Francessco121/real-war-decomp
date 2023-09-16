# KVAG/ADPCM
Real War stores audio files in the ADPCM format usually in the KVAG container.

These are `.VAG` files on disk.

KVAG Format:
| Offset | Size | Field    | Description |
|--------|------|----------|-------------|
| 0x0    | 4    | magic    | The string "KVAG" |
| 0x4    | 4    | size     | Size of ADPCM data in file (in bytes) |
| 0x8    | 4    | sampleRate | Audio sample rate |
| 0xC    | 2    | isStereo | 0 (Mono) or 1 (Stereo) |
| 0xE    | size | adpcmBytes | The actual ADPCM byte data |

The original game function for reading these files can be found at RAM `0x004d25e0`.

Fun fact: FFMPEG can read/write these files as of this patch: https://ffmpeg.org/pipermail/ffmpeg-devel/2020-February/256626.html
