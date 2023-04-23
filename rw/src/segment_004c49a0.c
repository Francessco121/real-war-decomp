#include "WINDOWS.H"

void rle_decode(unsigned short *in, unsigned short *out) {
    unsigned short var1;
    int var2;
    size_t i;
    int out_idx;
    int in_idx;

    out_idx = 0;
    in_idx = 0;

    while (TRUE) {
        // Next input word
        var1 = in[in_idx];

        // 0xFFFF marks end of sequence
        if (var1 == 0xffff) {
            break;
        }

        // If MSB is set...
        if (var1 & 0x8000) {
            // Remaining bits is the word length to copy
            var2 = var1 & 0x7fff;
            in_idx++; // Data to copy starts at next word (cur is the 'length')
            memcpy(&out[out_idx], &in[in_idx], var2 * 2);

            // Increment pointers
            in_idx += var2;
            out_idx += var2;
        } else {
            // Remaining bits is the word length to copy
            var2 = var1 & 0x7fff;
            in_idx++; // Data to copy starts at next word (cur is the 'length')
            
            for (i = 0; i < var2; i++) {
                out[out_idx + i] = in[in_idx];
            }

            in_idx += 1;
            out_idx += var2;
        }
    }
}
