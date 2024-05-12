# KVAG/ADPCM
Real War stores audio files in the 4-bit ADPCM format usually in the KVAG container. A couple files do not start with a KVAG header and instead are just raw mono ADPCM with a sample rate of 22050. These files seem to be inspired by Sony's VAG file format, which also uses 4-bit ADPCM.

These are `.VAG` files on disk.

The original game function for reading these files can be found at RAM `0x004d25e0`.

Fun fact: FFmpeg can read/write these files as of this patch: https://ffmpeg.org/pipermail/ffmpeg-devel/2020-February/256626.html

## File Format (with KVAG header)
All numerics are little-endian and unsigned.

| Offset | Size | Field    | Description |
|--------|------|----------|-------------|
| 0x0    | 4    | magic    | The string "KVAG" |
| 0x4    | 4    | size     | Size of ADPCM data * |
| 0x8    | 4    | sampleRate | Audio sample rate |
| 0xC    | 2    | isStereo | 0 (Mono) or 1 (Stereo) |
| 0xE    | size * | adpcmBytes | The actual ADPCM byte data |

\* The `size` field is larger than the number of bytes actually present in the file for all stereo KVAG files found in the game. It's unclear whether this is intentional or not (the game doesn't seem to reconcile this) but interpreting the missing bytes as zeroes appears to be correct.

## ADPCM Compression
For mono, every 4-bits of ADPCM is a single sample. For stereo, every 4-bits is also a single sample but only for one channel (either left or right, alternating). For each byte, the low-nibble is the left channel and the high-nibble is right.

Each sample can be decompressed using the standard 4-bit ADPCM to 16-bit linear decompression algorithm. For stereo, the emitted decompressed 16-bit samples should alternate between the left and right channels (with the left coming before the right).
