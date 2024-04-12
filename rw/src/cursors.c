#include <STDIO.H>

#include "types.h"
#include "undefined.h"
#include "virtual_memory.h"

char DAT_0051e100[256];

int32 gCurrentCursorIdx;

extern void FUN_004019b0(int32 param1);
extern int32 get_tga_file_length(char *path);
extern uint16 *load_targa_file(char *path, TextureFile *tex);
extern int32 FUN_00403720(uint16 *texBytes, uint16 *texBytes2, int32 width, int32 height, int32 textureId);
extern int32 FUN_004c7170(TextureFile*, TextureFile*);

void load_cursor_texture_frames(int32 idx, int32 frames, char *cursorName) {
    int32 i;
    int32 tgaLength;
    
    if (gCursorTextures[idx].texture.data != NULL) {
        custom_free(&gCursorTextures[idx].texture.data);
    }

    gCursorTextures[idx].texture.data = NULL;

    for (i = 0; i < frames; i++) {
        if (gD3DDeviceFound && gCursorTextures[idx].frames[i].textureId > 0) {
            FUN_004019b0(gCursorTextures[idx].frames[i].textureId);
        }

        gCursorTextures[idx].frames[i].textureId = 0;

        if (gCursorTextures[idx].frames[i].data != NULL) {
            custom_free(&gCursorTextures[idx].frames[i].data);
        }

        gCursorTextures[idx].frames[i].data = NULL;

        sprintf(DAT_0051e100, "data\\cursor\\%s%02d.tga", cursorName, i + 1);
        tgaLength = get_tga_file_length(DAT_0051e100);

        if (tgaLength != 0) {
            if (!gD3DDeviceFound && i == 0) {
                load_targa_file(DAT_0051e100, &gCursorTextures[idx].texture);
            }

            load_targa_file(DAT_0051e100, &gCursorTextures[idx].frames[i]);

            if ((i & 1) != 0) {
                if (gD3DDeviceFound) {
                    gCursorTextures[idx].frames[i - 1].textureId = FUN_00403720(
                        gCursorTextures[idx].frames[i - 1].data,
                        gCursorTextures[idx].frames[i].data,
                        gCursorTextures[idx].frames[i - 1].width,
                        gCursorTextures[idx].frames[i - 1].height,
                        0);
                } else {
                    FUN_004c7170(
                        &gCursorTextures[idx].frames[i - 1], 
                        &gCursorTextures[idx].frames[i]);
                }
            }
        }
    }

    DAT_0051b8e0 = 0;
    gCursorTextures[gCurrentCursorIdx].currentFrame = 0;
    gCursorTextures[idx].numFrames = frames;
}
