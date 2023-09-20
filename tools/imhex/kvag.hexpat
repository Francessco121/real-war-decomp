#include <std/mem.pat>

struct KVAGHeader {
    char magic[4];
    u32 dataSize;
    u32 sampleRate;
    u16 stereo;
};

struct KVAG {
    if (has_header()) {
        KVAGHeader header;
        u8 adpcmBytes[header.dataSize];
    } else {
        // File is just raw mono ADPCM with a 22050 sample rate
        u8 adpcmBytes[sizeof($)];
    }
};

fn has_header() {
    return std::mem::read_unsigned(0, 1) == 'K'
        && std::mem::read_unsigned(1, 1) == 'V'
        && std::mem::read_unsigned(2, 1) == 'A'
        && std::mem::read_unsigned(3, 1) == 'G';
};

KVAG kvag @ 0x0;