#include "WINDOWS.H"

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
void rle_decode(WORD *in, WORD *out) {
    WORD ctrl;
    unsigned int sequenceLen; // in words, not bytes
    size_t i;
    int outIdx;
    int inIdx;

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
