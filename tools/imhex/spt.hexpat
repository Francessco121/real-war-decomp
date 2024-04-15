#include <std/mem.pat>

bitfield SPTHeader  {
    frameCount : 30;
    padding : 1;
    isRle : 1;
};

struct SPTFrame {
    u32 pointer;
    u32 width @ pointer;
    u32 height @ pointer + 4;
    if (header.isRle) {
        // RLE ends with 0xFFFFFFFF
        u16 pixels[while(std::mem::read_unsigned($ - 4, 4) != 0xFFFFFFFF)] @ pointer + 8;
    } else {
        u16 pixels[width * height] @ pointer + 8;
    }
};

SPTHeader header @ 0x0;
SPTFrame frames[header.frameCount] @ sizeof(header);