#include "WINDOWS.H"

void FUN_004c49a0(unsigned short *in, unsigned short *out) {
    unsigned short var1;
    unsigned short var3;
    unsigned short var2;
    size_t i;
    int in_idx;
    int out_idx;

    in_idx = 0;
    out_idx = 0;

    while (TRUE) {
        var1 = in[in_idx];

        if (var1 == 0xffff) {
            break;
        }

        if (var1 & 0x8000) {
            var2 = var1 & 0x7fff;
            in_idx++;
            memcpy(&out[out_idx], &in[in_idx], var2);

            in_idx += var2;
            out_idx += var2;
        } else {
            in_idx++;
            //var2 = var1 & 0x7fff;
            for (i = 0; i < (var1 & 0x7fff); i++) {
                out[out_idx++] = in[in_idx];
            }

            in_idx += 1;
            //out_idx += var2;
        }
    }
}
