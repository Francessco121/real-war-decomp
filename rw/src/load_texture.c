#include <WINDOWS.H>

void bmp_pallete_rgb888_to_rgb1555(byte *pallete) {
    int i;
    byte r, g, b;
    byte *ptr = pallete + 2;

    for (i = 0; i < 256; i++) {
        r = ptr[-2] / 8;
        g = ptr[-1] / 8;
        b = ptr[0]  / 8;

        *((short*)pallete) = (r << 5 | g) << 5 | b;

        ptr += 3;
        pallete += 2;
    }
}

#pragma ASM_FUNC load_texture
