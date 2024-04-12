#include "types.h"
#include "undefined.h"
#include "virtual_memory.h"

uint16 *FUN_004c7080(TextureFile *baseTex, TextureFile *alphaTex) {
    uint32 pixelCount;
    uint16 *allocBytes;
    int32 i;
    uint8 var2;

    pixelCount = baseTex->width * baseTex->height;
    allocBytes = (uint16*)custom_alloc(((pixelCount + 1) >> 1) + pixelCount * 2);

    memcpy(allocBytes, baseTex->data, baseTex->width * baseTex->height * 2);

    for (i = 0; i < (baseTex->width * baseTex->height); i++) {
        uint16 alphaWord;
        uint16 alphaRgbAverage;

        alphaWord = alphaTex->data[i];
        alphaRgbAverage = (uint16)((((alphaWord >> 10) & 0x1f) + ((alphaWord >> 5) & 0x1f) + (alphaWord & 0x1f)) / 3);

        if ((i & 1) == 0) {
            var2 = (uint8)(alphaRgbAverage << 4);
        } else {
            var2 = (uint8)(var2 | (alphaRgbAverage & 0xf));
            ((uint8*)allocBytes)[(i >> 1) + (baseTex->width * baseTex->height) * 2] = var2;
        }

        if ((alphaRgbAverage & 0x10) != 0) {
            ((uint8*)allocBytes)[i * 2 + 1] |= 0x80; // set MSB
        } else {
            allocBytes[i] &= 0x7fff; // unset MSB
        }

    }

    return allocBytes;
}
