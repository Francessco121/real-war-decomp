struct KVAGHeader {
    char magic[4];
    u32 dataSize;
    u32 sampleRate;
    u16 stereo;
};

KVAGHeader header @ 0x0;
u8 adpcmBytes[header.dataSize] @ 0xe;