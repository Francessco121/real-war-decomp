#include "types.h"

void bmp_pallete_rgb888_to_rgb1555(uint8 *pallete) {
    int i;
    uint8 r, g, b;
    uint8 *ptr = pallete + 2;

    for (i = 0; i < 256; i++) {
        r = (uint8)(ptr[-2] / 8);
        g = (uint8)(ptr[-1] / 8);
        b = (uint8)(ptr[0]  / 8);

        *((uint16*)pallete) = (uint16)((r << 5 | g) << 5 | b);

        ptr += 3;
        pallete += 2;
    }
}
