#include "data.h"
#include "types.h"
#include "undefined.h"
#include "virtual_memory.h"
#include "window.h"

extern TextureFile DAT_00945f60[4];
extern TextureFile DAT_00fe0200[4];
extern int8 DAT_00ed3d28;

extern uint16* FUN_004b9000(uint16*,TextureFile*);
extern uint16* FUN_004c5f40(uint16*,uint16*,uint16*,int32);
extern int32 FUN_004055f0(uint16*,int32);
extern int32 FUN_00406a30(int32 textureId);
extern int16* FUN_004c71a0(uint16*,int32);

void load_spt_file(char *path, TextureFile *param_2, int32 param_3, int32 param_4) {
    size_t sptFileLength;
    uint16 *sptBytes;

    size_t s16FileLength;
    char s16Path[256];
    
    if (get_data_file_length(path) != 0) {
        if (!gD3DDeviceFound || param_3 == 0) {
            int32 i = 0;

            for (i = 0; i < 256; i++) {
                s16Path[i] = path[i];

                if (s16Path[i] == '.') {
                    break;
                }
            }

            s16Path[i + 0] = '.';
            s16Path[i + 1] = 'S';
            s16Path[i + 2] = '1';
            s16Path[i + 3] = '6';
            s16Path[i + 4] = '\0';

            s16FileLength = get_data_file_length(s16Path);

            if (s16FileLength != 0) {
                uint16 *s16Bytes;

                s16Bytes = (uint16*)custom_alloc(s16FileLength);
                read_data_file(&s16Path, s16Bytes);

                if (DAT_00ed3d28 >= 0) {
                    s16Bytes = FUN_004b9000(s16Bytes, &DAT_00945f60[DAT_00ed3d28]);
                }

                param_2->data = s16Bytes;
                param_2->textureId = 0;

                return;
            }
        }

        sptFileLength = get_data_file_length(path);
        sptBytes = (uint16*)custom_alloc(sptFileLength);
        read_data_file(path, sptBytes);

        if (DAT_00ed3d28 >= 0) {
            sptBytes = FUN_004c5f40(sptBytes, &DAT_00945f60[DAT_00ed3d28].data, &DAT_00fe0200[DAT_00ed3d28].data, 2);
        }

        param_2->data = sptBytes;
        param_2->textureId = 0;

        if (gD3DDeviceFound && param_3 != 0) {
            uint32* var1;
            param_2->textureId = FUN_004055f0(sptBytes, param_4);

            custom_free(&param_2->data);
            var1 = custom_alloc(32);

            param_2->data = var1;

            *var1 = FUN_00406a30(param_2->textureId);
            return;
        }

        if (param_4 != 0) {
            uint16 *var1;

            var1 = FUN_004c71a0(sptBytes, param_4);
            
            custom_free(&param_2->data);
            param_2->data = var1;
            param_2->textureId = 0;
            return;
        }
    } else {
        sprintf(&gTempString, "Bad Anim Filename\n%s", path);
        display_messagebox_and_exit(&gTempString);
    }
}
