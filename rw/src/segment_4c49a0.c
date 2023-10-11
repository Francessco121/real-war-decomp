#include <STRING.H>

#include "types.h"

/**
 * Decodes a run-length encoded string.
 * 
 * The string is expected to have control words that specify whether
 * the following data is a run or data to be copied as is. The MSB
 * signifies this. The remaining bits specify the length of bytes.
 * After a control word, the next n number of words is the data.
 * 
 * This process repeats until 0xFFFF is encountered, which terminates
 * the RLE string.
 * 
 * [in] - String to decode.
 * [out] - Decoded output.
 */
void rle_decode(const uint16 *in, uint16 *out) {
    uint16 ctrl;
    uint32 sequenceLen; // in words, not bytes
    uint32 i;
    int32 outIdx;
    int32 inIdx;

    outIdx = 0;
    inIdx = 0;

    while (TRUE) {
        // Next control word
        ctrl = in[inIdx];

        // 0xFFFF marks end of string
        if (ctrl == 0xffff) {
            break;
        }

        // Check MSB
        if (ctrl & 0x8000) {
            // Copy next n words as is
            sequenceLen = ctrl & 0x7fff;
            inIdx++;
            memcpy(&out[outIdx], &in[inIdx], sequenceLen * 2);

            inIdx += sequenceLen;
            outIdx += sequenceLen;
        } else {
            // Repeat next word n number of times
            sequenceLen = ctrl & 0x7fff;
            inIdx++;
            
            for (i = 0; i < sequenceLen; i++) {
                out[outIdx + i] = in[inIdx];
            }

            inIdx += 1;
            outIdx += sequenceLen;
        }
    }
}
