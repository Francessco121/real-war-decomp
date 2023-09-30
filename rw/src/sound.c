#include <WINDOWS.H>
#include <DSOUND.H>

#include "data.h"
#include "strings.h"
#include "undefined.h"
#include "virtual_memory.h"

extern byte gSoundSystemInitialized;
extern int gADPCMIndexTable[16];
extern int gADPCMStepsizeTable[89];
extern short gADPCMPredictor;
extern char gADPCMIndex;
extern short gADPCMPredictor2;
extern char gADPCMIndex2;

extern HRESULT gHResult1;
extern HRESULT gHResult2;

/**
 * Decompresses 4-bit ADPCM into 16-bit PCM.
 */
void adpcm_decompress(char *input, short *output, int length);
/**
 * Decompresses 4-bit ADPCM into two 16-bit PCM streams.
 */
void adpcm_decompress_stereo(char *input, short *output1, short *output2, int length);

void write_bytes_to_sound_buffer(LPDIRECTSOUNDBUFFER soundBuffer, char *data, DWORD length) {
    char *lpvAudioPtr1;
    DWORD dwAudioBytes1;
    char *lpvAudioPtr2;
    DWORD dwAudioBytes2;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    gHResult1 = IDirectSoundBuffer_Lock(soundBuffer, 
        /*dwWriteCursor*/ 0,
        /*dwWriteBytes*/ length,
        /*lplpvAudioPtr1*/ &lpvAudioPtr1,
        /*lpdwAudioBytes1*/ &dwAudioBytes1,
        /*lplpvAudioPtr2*/ &lpvAudioPtr2,
        /*lpdwAudioBytes2*/ &dwAudioBytes2,
        /*dwFlags*/ 0);
    
    if (gHResult1 != DS_OK) {
        return;
    }

    memcpy(lpvAudioPtr1, data, dwAudioBytes1);

    if (dwAudioBytes2 != 0) {
        memcpy(lpvAudioPtr2, &data[dwAudioBytes1], dwAudioBytes2);
    }

    IDirectSoundBuffer_Unlock(soundBuffer, lpvAudioPtr1, dwAudioBytes1, lpvAudioPtr2, dwAudioBytes2);
}

void FUN_004d2100(
    IDirectSoundBuffer *soundBuffer1, 
    IDirectSoundBuffer *soundBuffer2,
    char *adpcmBytes,
    size_t adpcmLength,
    int isStereo
) {
    LPVOID audioPtr1_1;
    DWORD audioBytes1_1;
    LPVOID audioPtr2_1;
    DWORD audioBytes2_1;

    LPVOID audioPtr1_2;
    DWORD audioBytes1_2;
    LPVOID audioPtr2_2;
    DWORD audioBytes2_2;

    if (!gSoundSystemInitialized) {
        return;
    }

    if (isStereo) {
        gHResult1 = IDirectSoundBuffer_Lock(soundBuffer1, 
            /*dwWriteCursor*/ 0,
            /*dwWriteBytes*/ adpcmLength / 2,
            /*lplpvAudioPtr1*/ &audioPtr1_1,
            /*lpdwAudioBytes1*/ &audioBytes1_1,
            /*lplpvAudioPtr2*/ &audioPtr2_1,
            /*lpdwAudioBytes2*/ &audioBytes2_1,
            /*dwFlags*/ 0);
        
        gHResult2 = IDirectSoundBuffer_Lock(soundBuffer2, 
            /*dwWriteCursor*/ 0,
            /*dwWriteBytes*/ adpcmLength / 2,
            /*lplpvAudioPtr1*/ &audioPtr1_2,
            /*lpdwAudioBytes1*/ &audioBytes1_2,
            /*lplpvAudioPtr2*/ &audioPtr2_2,
            /*lpdwAudioBytes2*/ &audioBytes2_2,
            /*dwFlags*/ 0);
        
        if (gHResult1 == DS_OK && gHResult2 == DS_OK) {
            adpcm_decompress_stereo(
                adpcmBytes, 
                (short*)audioPtr1_1, 
                (short*)audioPtr1_2, 
                audioBytes1_1 / 2);

            if (audioBytes2_1 != 0) {
                adpcm_decompress_stereo(
                    adpcmBytes + (audioBytes1_1 / 2), 
                    (short*)audioPtr2_1, 
                    (short*)audioPtr2_2, 
                    audioBytes2_1 / 2);
            }

            IDirectSoundBuffer_Unlock(soundBuffer1, audioPtr1_1, audioBytes1_1, audioPtr2_1, audioBytes2_1);
            IDirectSoundBuffer_Unlock(soundBuffer2, audioPtr1_2, audioBytes1_1, audioPtr2_2, audioBytes2_1);
        }
    } else {
        gHResult1 = IDirectSoundBuffer_Lock(soundBuffer1, 
            /*dwWriteCursor*/ 0,
            /*dwWriteBytes*/ adpcmLength,
            /*lplpvAudioPtr1*/ &audioPtr1_1,
            /*lpdwAudioBytes1*/ &audioBytes1_1,
            /*lplpvAudioPtr2*/ &audioPtr2_1,
            /*lpdwAudioBytes2*/ &audioBytes2_1,
            /*dwFlags*/ 0);
        
        if (gHResult1 == DS_OK) {
            adpcm_decompress(adpcmBytes, (short*)audioPtr1_1, audioBytes1_1 / 2);

            if (audioBytes2_1 != 0) {
                adpcm_decompress(adpcmBytes + (audioBytes1_1 / 4), (short*)audioPtr2_1, audioBytes2_1 / 2);
            }

            IDirectSoundBuffer_Unlock(soundBuffer1, audioPtr1_1, audioBytes1_1, audioPtr2_1, audioBytes2_1);
        }
    }
}

void display_message_and_exit_2(char* message) {
    display_message_and_exit(message);
}

void adpcm_decompress(char *input, short *output, int length) {
    int index;
    int step;
    int curByte;
    int nibble;
    int nibbleIdx;
    int predictor;
    int diff;
    int signBit;
    char *inputPtr;
    short *outputPtr;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    outputPtr = output;
    inputPtr = input;

    index = gADPCMIndex;
    predictor = gADPCMPredictor;
    step = gADPCMStepsizeTable[index];
    nibbleIdx = 0;

    while (length > 0) {
        if (nibbleIdx) {
            nibble = curByte & 0xF;
        } else {
            curByte = *(inputPtr++);
            nibble = (curByte >> 4) & 0xF;
        }

        nibbleIdx = !nibbleIdx;

        index += gADPCMIndexTable[nibble];

        if (index < 0) {
            index = 0;
        } else if (index > 88) {
            index = 88;
        }

        signBit = nibble & 8;
        nibble = nibble & 7;

        diff = step >> 3;
        if (nibble & 4) diff += step;
        if (nibble & 2) diff += step >> 1;
        if (nibble & 1) diff += step >> 2;

        if (signBit) {
            predictor -= diff;
        } else {
            predictor += diff;
        }

        if (predictor > 32767) {
            predictor = 32767;
        } else if (predictor < -32768) {
            predictor = -32768;
        }

        step = gADPCMStepsizeTable[index];
        *(outputPtr++) = predictor;

        length--;
    }

    gADPCMPredictor = predictor;
    gADPCMIndex = index;
}

void adpcm_decompress_stereo(char *input, short *rightChannelOutput, short *leftChannelOutput, int length) {
    int index1;
    int index2;
    int step1;
    int step2;
    int nibble;
    int lowerNibble;
    int upperNibble;
    int predictor1;
    int predictor2;
    int diff1;
    int diff2;
    int signBit1;
    int signBit2;
    char *inputPtr;
    short *rightChannelPtr;
    short *leftChannelPtr;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    rightChannelPtr = rightChannelOutput;
    leftChannelPtr = leftChannelOutput;
    inputPtr = input;

    predictor1 = gADPCMPredictor;
    predictor2 = gADPCMPredictor2;

    index1 = gADPCMIndex;
    index2 = gADPCMIndex2;
    
    step1 = gADPCMStepsizeTable[index1];
    step2 = gADPCMStepsizeTable[index2];

    while (length > 0) {
        nibble = *(inputPtr++);
        upperNibble = (nibble >> 4) & 0xF;
        lowerNibble = nibble & 0xF;

        index1 += gADPCMIndexTable[upperNibble];
        index2 += gADPCMIndexTable[lowerNibble];

        if (index1 < 0) {
            index1 = 0;
        } else if (index1 > 88) {
            index1 = 88;
        }

        if (index2 < 0) {
            index2 = 0;
        } else if (index2 > 88) {
            index2 = 88;
        }

        signBit1 = upperNibble & 8;
        signBit2 = lowerNibble & 8;
        
        upperNibble = upperNibble & 7;
        lowerNibble = lowerNibble & 7;

        diff1 = step1 >> 3;
        if (upperNibble & 4) diff1 += step1;
        if (upperNibble & 2) diff1 += step1 >> 1;
        if (upperNibble & 1) diff1 += step1 >> 2;

        diff2 = step2 >> 3;
        if (lowerNibble & 4) diff2 += step2;
        if (lowerNibble & 2) diff2 += step2 >> 1;
        if (lowerNibble & 1) diff2 += step2 >> 2;

        if (signBit1) {
            predictor1 -= diff1;
        } else {
            predictor1 += diff1;
        }

        if (signBit2) {
            predictor2 -= diff2;
        } else {
            predictor2 += diff2;
        }

        if (predictor1 > 32767) {
            predictor1 = 32767;
        } else if (predictor1 < -32768) {
            predictor1 = -32768;
        }

        if (predictor2 > 32767) {
            predictor2 = 32767;
        } else if (predictor2 < -32768) {
            predictor2 = -32768;
        }

        step1 = gADPCMStepsizeTable[index1];
        step2 = gADPCMStepsizeTable[index2];

        *(rightChannelPtr++) = predictor1;
        *(leftChannelPtr++) = predictor2;

        length--;
    }

    gADPCMPredictor = predictor1;
    gADPCMIndex = index1;

    gADPCMPredictor2 = predictor2;
    gADPCMIndex2 = index2;
}

/**
 * Reads ADPCM bytes from a file.
 * 
 * The file can either be raw ADPCM bytes or a KVAG container.
 */
char* read_adpcm_file(char* file_path) {
    long fileLength;
    char *adpcmBuf;
    
    if (!gSoundSystemInitialized) {
        return NULL;
    }

    fileLength = get_data_file_length(file_path);

    if (fileLength != 0) {
        // Allocate space for the file + KVAG header (in case we need to add our own header)
        adpcmBuf = (char*)custom_alloc(fileLength + 16);
        if (adpcmBuf == NULL) {
            display_message_and_exit_2(str_couldnt_malloc_adpcm_buf);
        }

        // Read KVAG header
        read_data_file_partial(file_path, adpcmBuf, 16);

        if (adpcmBuf[0] == 'K' &&
            adpcmBuf[1] == 'V' &&
            adpcmBuf[2] == 'A' &&
            adpcmBuf[3] == 'G'
        ) {
            // KVAG header present, just read the file as is since this is the format we want
            read_data_file(file_path, adpcmBuf);
        } else {
            // File is just ADPCM bytes without the KVAG header, so add our own header and
            // read in the file after it

            // data size (u32)
            adpcmBuf[4] = (char)fileLength;
            adpcmBuf[5] = (char)(fileLength >> 8);
            adpcmBuf[6] = (char)(fileLength >> 16);
            adpcmBuf[7] = (char)((unsigned long)fileLength >> 24); // why is this SHR and the others SAR?
            // sample rate (u32)
            adpcmBuf[8] = 0;
            adpcmBuf[9] = 0;
            adpcmBuf[10] = 0;
            adpcmBuf[11] = 0;
            // is stereo (u16)
            adpcmBuf[12] = 0;
            adpcmBuf[13] = 0;

            read_data_file(file_path, &adpcmBuf[0xe]);
        }

        return adpcmBuf;
    } else {
        display_message(str_bad_or_missing_adpcm_file, file_path);
        return NULL;
    }
}
