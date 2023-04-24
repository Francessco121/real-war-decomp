struct BigFileEntry {
    char path[64];
    u32 pathHash;
    u32 byteOffset;
    u32 sizeBytes;
    u8 rawData[sizeBytes] @ byteOffset;
};

struct BigFile {
    u32 entryCount;
    BigFileEntry entries[entryCount];
};

BigFile bigfile @ 0x0;