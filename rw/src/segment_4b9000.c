#include "types.h"
#include "undefined.h"

void *FUN_004b9000(void *data, TextureFile *tex) {
    int32 i;
    int32 frameCount;
    int32 *header;

    int32 someColorR;
    int32 someColorG;
    int32 someColorB;

    header = (int32*)data;

    frameCount = header[0] & 0x3fffffff;

    someColorR = (tex->data[1] >> 10) & 0x1f;
    someColorG = (tex->data[1] >> 5) & 0x1f;
    someColorB = (tex->data[1] >> 0) & 0x1f;

    for (i = 0; i < frameCount; i++) {
        int32 paletteLength;
        uint8 *framePtr;
        uint16 *palettePtr;
        int32 j;

        framePtr = ((uint8*)data) + header[i + 1]; // +1 to skip frame count dword
        palettePtr = (uint16*)(framePtr + 8); // +8 to skip width/height dwords
        paletteLength = palettePtr[0];

        for (j = 1; j <= paletteLength; j++) {
            int32 r;
            int32 g;
            int32 b;
            int32 avg;

            r = (palettePtr[j] >> 10) & 0x1f;
            g = (palettePtr[j] >> 5) & 0x1f;
            b = (palettePtr[j] >> 0) & 0x1f;

            avg = (r + g + b) / 3;

            r += (avg * someColorR) >> 5;
            g += (avg * someColorG) >> 5;
            b += (avg * someColorB) >> 5;

            if (r > 31) {
                r = 31;
            }
            if (g > 31) {
                g = 31;
            }
            if (b > 31) {
                b = 31;
            }

            palettePtr[j] = (uint16)((r << 10) | (g << 5) | b);
        }
    }

    return data;
}
