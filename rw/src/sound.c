#include <WINDOWS.H>
#include <DSOUND.H>

#include "create_window.h"
#include "data.h"
#include "strings.h"
#include "undefined.h"
#include "virtual_memory.h"

#define NUM_SOUND_BUFFERS 18

#define KVAG_ADPCM_START 0xE
#define KVAG_ADPCM_LENGTH(bytes) ((bytes)[7] << 24) + ((bytes)[6] << 16) + ((bytes)[5] << 8) + (bytes)[4]
#define KVAG_SAMPLE_RATE(bytes) ((bytes)[0xb] << 24) + ((bytes)[0xa] << 16) + ((bytes)[9] << 8) + (bytes)[8]
#define KVAG_IS_STEREO(bytes) ((bytes)[0xd] << 8) + (bytes)[0xc]

typedef struct {
    /*0x0*/  int field0x0;
    /*0x4*/  int field0x4;
    /*0x8*/  int field0x8;
    /*0xc*/  unsigned int field0xc;
    // Byte length of ADPCM data.
    /*0x10*/ unsigned int adpcmDataSize;
    /*0x14*/ unsigned int field0x14;
    /*0x18*/ FILE *file;
    // Pointer to KVAG header.
    /*0x18*/ char *kvagBytes;
    // Pointer to KVAG ADPCM bytes.
    /*0x20*/ char *adpcmBytes;
    /*0x24*/ int isStereo;
    /*0x28*/ int adpcmIndex1;
    /*0x2c*/ int adpcmPredictor1;
    /*0x30*/ int adpcmIndex2;
    /*0x34*/ int adpcmPredictor2;
    /*0x38*/ char filePath[256];
    /*0x138*/ unsigned int field0x138;
} SomeAudioStruct;

extern byte gSoundSystemInitialized;

extern int gADPCMIndexTable[16];
extern int gADPCMStepsizeTable[89];
extern short gADPCMPredictor;
extern char gADPCMIndex;
extern short gADPCMPredictor2;
extern char gADPCMIndex2;

extern LPDIRECTSOUND gDirectSound;

extern LPDIRECTSOUNDBUFFER gSoundBuffers1[NUM_SOUND_BUFFERS];
extern LPDIRECTSOUNDBUFFER gSoundBuffers2[NUM_SOUND_BUFFERS];
extern LPDIRECTSOUNDBUFFER sSoundBuffer1;
extern LPDIRECTSOUNDBUFFER sSoundBuffer2;

extern SomeAudioStruct gSomeAudioStructs[2];

extern char DAT_00574a00[NUM_SOUND_BUFFERS];
extern int DAT_005a4f88[2];

extern unsigned int DAT_0053ee00[NUM_SOUND_BUFFERS];

extern char DAT_0051e3e0[2][66560];
extern char DAT_00546f80[2][66560];

extern int DAT_0057137c;

extern WAVEFORMATEX DAT_00546e60;

extern DWORD sSoundStatus;

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
void release_sound_buffers(int idx);
void sound_func_004d35a0(int idx);
void sound_func_004d3f60();
void sound_func_004d4060();
void sound_func_004d4090();
void free_audio_struct_buffer(int idx);
void sound_set_pan_1(int, int, int);
void sound_set_volume_1(int, int, int);
void sound_set_volume_2(int, int, int);
/**
 * Sets the pitch of a sound on a scale from 0-1024,
 * where 1024 is the normal pitch and 0 is effectively stopped.
 */
void sound_set_pitch(int pitch, int idx);

void init_sound_system() {
    int i;

    gSoundSystemInitialized = FALSE;

    gHResult1 = DirectSoundCreate(NULL, &gDirectSound, NULL);

    if (gHResult1 == DS_OK) {
        gHResult1 = IDirectSound_SetCooperativeLevel(gDirectSound, gWndHandle, DSSCL_EXCLUSIVE);

        if (gHResult1 == DS_OK) {
            memset(gSomeAudioStructs, 0, sizeof(gSomeAudioStructs));
            memset(DAT_00574a00, 0, sizeof(DAT_00574a00));
            memset(gSoundBuffers1, 0, sizeof(gSoundBuffers1));
            memset(gSoundBuffers2, 0, sizeof(gSoundBuffers2));

            for (i = 0; i < 2; i++) {
                DAT_005a4f88[i] = 16 + i;
            }

            gSoundSystemInitialized = TRUE;
        } else {
            display_message(str_SoundSystemNotInitialized);
        }
    } else {
        display_message(str_SoundSystemNotInitialized);
    }
}

void deinit_sound_system() {
    int i;

    if (!gSoundSystemInitialized) {
        return;
    }

    sound_func_004d3f60();
    sound_func_004d4060();
    sound_func_004d4090();

    for (i = 0; i < NUM_SOUND_BUFFERS; i++) {
        release_sound_buffers(i);
    }

    IDirectSound_Release(gDirectSound);

    gSoundSystemInitialized = FALSE;
}

void sound_func_004d1d90() {
    int i;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    for (i = 0; i < NUM_SOUND_BUFFERS; i++) {
        sSoundBuffer1 = gSoundBuffers1[i];
        sSoundBuffer2 = gSoundBuffers2[i];

        if (DAT_00574a00[i] == 2) {
            gHResult1 = IDirectSoundBuffer_GetStatus(sSoundBuffer1, &sSoundStatus);

            if (gHResult1 == DS_OK && 
                ((sSoundStatus & DSBSTATUS_PLAYING) != DSBSTATUS_PLAYING || !handle_window_focus_change())
            ) {
                IDirectSoundBuffer_Stop(sSoundBuffer1);
                if (sSoundBuffer2 != NULL) {
                    IDirectSoundBuffer_Stop(sSoundBuffer2);
                }

                if (i < 16) {
                    IDirectSoundBuffer_Release(sSoundBuffer1);
                    if (sSoundBuffer2 != NULL) {
                        IDirectSoundBuffer_Release(sSoundBuffer2);
                    }

                    gSoundBuffers1[i] = NULL;
                    gSoundBuffers2[i] = NULL;
                }
                
                DAT_00574a00[i] = 0;
                continue;
            }

            if (gHResult1 != DS_OK) {
                DAT_00574a00[i] = 0;
            }
        }
    }
}

void sound_func_004d1e60(int idx) {
    if (!gSoundSystemInitialized) {
        return;
    }

    sound_func_004d35a0(idx);
}

BOOL is_sound_playing(int idx) {
    int playing;
    
    if (!gSoundSystemInitialized) {
        return TRUE;
    }

    playing = FALSE;

    if (DAT_00574a00[idx] != 0) {
        sSoundBuffer1 = gSoundBuffers1[idx];
        if (sSoundBuffer1 != NULL) {
            gHResult1 = IDirectSoundBuffer_GetStatus(sSoundBuffer1, &sSoundStatus);
            if ((sSoundStatus & DSBSTATUS_PLAYING) == DSBSTATUS_PLAYING) {
                playing = TRUE;
            }
        }
    }

    return playing;
}

void play_sound(int idx) {
    if (!gSoundSystemInitialized) {
        return;
    }

    if (DAT_00574a00[idx] == 0) {
        return;
    }

    sSoundBuffer1 = gSoundBuffers1[idx];
    sSoundBuffer2 = gSoundBuffers2[idx];

    IDirectSoundBuffer_Play(sSoundBuffer1, 0, 0, 0);

    if (sSoundBuffer2 != NULL) {
        IDirectSoundBuffer_Play(sSoundBuffer2, 0, 0, 0);
    }
}

void play_sound_looping(int idx) {
    if (!gSoundSystemInitialized) {
        return;
    }

    if (DAT_00574a00[idx] == 0) {
        return;
    }

    sSoundBuffer1 = gSoundBuffers1[idx];
    sSoundBuffer2 = gSoundBuffers2[idx];

    IDirectSoundBuffer_Play(sSoundBuffer1, 0, 0, DSBPLAY_LOOPING);

    if (sSoundBuffer2 != NULL) {
        IDirectSoundBuffer_Play(sSoundBuffer2, 0, 0, DSBPLAY_LOOPING);
    }
}

void release_sound_buffers(int idx) {
    if (!gSoundSystemInitialized) {
        return;
    }

    if (gSoundBuffers1[idx] != NULL) {
        sSoundBuffer1 = gSoundBuffers1[idx];
        gHResult1 = IDirectSoundBuffer_GetStatus(sSoundBuffer1, &sSoundStatus);

        if (gHResult1 == DS_OK) {
            IDirectSoundBuffer_Stop(sSoundBuffer1);
            IDirectSoundBuffer_Release(sSoundBuffer1);
            gSoundBuffers1[idx] = NULL;
        }

        sSoundBuffer2 = gSoundBuffers2[idx];
        if (sSoundBuffer2 != NULL) {
            gHResult1 = IDirectSoundBuffer_GetStatus(sSoundBuffer2, &sSoundStatus);
            
            if (gHResult1 == DS_OK) {
                IDirectSoundBuffer_Stop(sSoundBuffer2);
                IDirectSoundBuffer_Release(sSoundBuffer2);
                gSoundBuffers2[idx] = NULL;
            }
        }
    }

    DAT_00574a00[idx] = 0;
}

void write_bytes_to_sound_buffer(IDirectSoundBuffer *soundBuffer, char *data, DWORD length) {
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

void write_adpcm_to_sound_buffers(
    IDirectSoundBuffer *soundBuffer1, 
    IDirectSoundBuffer *soundBuffer2,
    char *adpcmBytes,
    DWORD adpcmLength,
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
 * Reads KVAG bytes from a file.
 * 
 * The file can either be raw ADPCM bytes or a KVAG container.
 * If the file is just raw ADPCM, a header will be added to the returned bytes.
 */
char* read_kvag_file(char* filePath) {
    long fileLength;
    char *kvagBuf;
    
    if (!gSoundSystemInitialized) {
        return NULL;
    }

    fileLength = get_data_file_length(filePath);

    if (fileLength != 0) {
        // Allocate space for the file + KVAG header (in case we need to add our own header)
        kvagBuf = (char*)custom_alloc(fileLength + 16);
        if (kvagBuf == NULL) {
            display_message_and_exit_2(str_couldnt_malloc_adpcm_buf);
        }

        // Read KVAG header
        read_data_file_partial(filePath, kvagBuf, 16);

        if (kvagBuf[0] == 'K' &&
            kvagBuf[1] == 'V' &&
            kvagBuf[2] == 'A' &&
            kvagBuf[3] == 'G'
        ) {
            // KVAG header present, just read the file as is since this is the format we want
            read_data_file(filePath, kvagBuf);
        } else {
            // File is just ADPCM bytes without the KVAG header, so add our own header and
            // read in the file after it

            // data size (u32)
            kvagBuf[4] = (char)fileLength;
            kvagBuf[5] = (char)(fileLength >> 8);
            kvagBuf[6] = (char)(fileLength >> 16);
            kvagBuf[7] = (char)((unsigned long)fileLength >> 24); // why is this SHR and the others SAR?
            // sample rate (u32)
            kvagBuf[8] = 0;
            kvagBuf[9] = 0;
            kvagBuf[10] = 0;
            kvagBuf[11] = 0;
            // is stereo (u16)
            kvagBuf[12] = 0;
            kvagBuf[13] = 0;

            read_data_file(filePath, &kvagBuf[KVAG_ADPCM_START]);
        }

        return kvagBuf;
    } else {
        display_message(str_bad_or_missing_adpcm_file, filePath);
        return NULL;
    }
}

#ifdef NON_MATCHING
int sound_func_004d26c0(int idx, short *output1, short *output2, int length) {
    int i;
    int length2;
    int ret;
    int left;
    char buffer[64*4];

    if (!gSoundSystemInitialized) {
        return 0;
    }

    gADPCMIndex = gSomeAudioStructs[idx].adpcmIndex1;
    gADPCMPredictor = gSomeAudioStructs[idx].adpcmPredictor1;
    gADPCMIndex2 = gSomeAudioStructs[idx].adpcmIndex2;
    gADPCMPredictor2 = gSomeAudioStructs[idx].adpcmPredictor2;

    if (gSomeAudioStructs[idx].isStereo) {
        length2 = length;
        if (length == 8192) {
            length2 = 16384;
        }
        
        ret = 0;

        for (i = 64; i < length2; i += 64) {
            memset(buffer, 0, 64*4);

            if (gSomeAudioStructs[idx].file != NULL) {
                fread(buffer, 64, 1, gSomeAudioStructs[idx].file);
            } else {
                memcpy(buffer, gSomeAudioStructs[idx].adpcmBytes, 64);
                gSomeAudioStructs[idx].adpcmBytes += 64;
            }

            adpcm_decompress_stereo(buffer, output1, output2, 64);

            output2 += 64;
            output1 += 64;
            ret += 64;
        }

        left = length2 - ret;
        if (left > 0) {
            memset(buffer, 0, left);

            if (gSomeAudioStructs[idx].file != NULL) {
                fread(buffer, left, 1, gSomeAudioStructs[idx].file);
            } else {
                memcpy(buffer, gSomeAudioStructs[idx].adpcmBytes, left);
                gSomeAudioStructs[idx].adpcmBytes += left;
            }

            adpcm_decompress_stereo(buffer, output1, output2, left);
            ret = length2;
        }
    } else {
        length2 = length;
        ret = 0;

        for (i = 32; i < length2; i += 32) {
            memset(buffer, 0, 64*4);

            if (gSomeAudioStructs[idx].file != NULL) {
                fread(buffer, 32, 1, gSomeAudioStructs[idx].file);
            } else {
                memcpy(buffer, gSomeAudioStructs[idx].adpcmBytes, 32);
                gSomeAudioStructs[idx].adpcmBytes += 32;
            }

            adpcm_decompress(buffer, output1, 64);

            output1 += 64;
            ret += 32;
        }

        left = length2 - ret;
        if (left != 0) {
            memset(buffer, 0, left);

            if (gSomeAudioStructs[idx].file != NULL) {
                fread(buffer, left, 1, gSomeAudioStructs[idx].file);
            } else {
                memcpy(buffer, gSomeAudioStructs[idx].adpcmBytes, left);
                gSomeAudioStructs[idx].adpcmBytes += left;
            }

            adpcm_decompress(buffer, output1, left*2);
            ret = length2;
        }
    }

    gSomeAudioStructs[idx].adpcmIndex1 = gADPCMIndex;
    gSomeAudioStructs[idx].adpcmPredictor1 = gADPCMPredictor;
    gSomeAudioStructs[idx].adpcmIndex2 = gADPCMIndex2;
    gSomeAudioStructs[idx].adpcmPredictor2 = gADPCMPredictor2;

    return ret;
}
#else
int sound_func_004d26c0(int idx, short *output1, short *output2, int length);
#pragma ASM_FUNC sound_func_004d26c0 hasret
#endif

void sound_func_004d2a10(int idx, unsigned int sampleRate, int channels) {
    DSBUFFERDESC bufferDesc = {0};

    if (!gSoundSystemInitialized) {
        return;
    }

    DAT_005a4f88[idx] = idx + 16;

    memset(&bufferDesc, 0, sizeof(DSBUFFERDESC));

    if (sampleRate == 0) {
        sampleRate = 22050;
    }

    if (gSoundBuffers1[DAT_005a4f88[idx]] != NULL) {
        gHResult1 = IDirectSoundBuffer_GetStatus(gSoundBuffers1[DAT_005a4f88[idx]], &sSoundStatus);
        
        if (gHResult1 == DS_OK) {
            IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[idx]]);
        }

        IDirectSoundBuffer_SetFrequency(gSoundBuffers1[DAT_005a4f88[idx]], sampleRate);

        memset(&DAT_00546f80[idx], 0, 65536);

        write_bytes_to_sound_buffer(gSoundBuffers1[DAT_005a4f88[idx]], DAT_00546f80[idx], 65536);

        if (gSoundBuffers2[DAT_005a4f88[idx]] != NULL) {
            gHResult1 = IDirectSoundBuffer_GetStatus(gSoundBuffers2[DAT_005a4f88[idx]], &sSoundStatus);
            
            if (gHResult1 == DS_OK) {
                IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[idx]]);
            }

            IDirectSoundBuffer_SetFrequency(gSoundBuffers2[DAT_005a4f88[idx]], sampleRate);

            memset(&DAT_0051e3e0[idx], 0, 65536);

            write_bytes_to_sound_buffer(gSoundBuffers2[DAT_005a4f88[idx]], DAT_0051e3e0[idx], 65536);
        }

        DAT_00574a00[DAT_005a4f88[idx]] = 1;
        DAT_0053ee00[DAT_005a4f88[idx]] = sampleRate;
        sound_set_volume_2(16384, 16384, idx);
        return;
    }

    DAT_00574a00[DAT_005a4f88[idx]] = 0;

    bufferDesc.dwSize = 36;
    bufferDesc.dwFlags = DSBCAPS_CTRLFREQUENCY | DSBCAPS_CTRLPAN | DSBCAPS_CTRLVOLUME;
    bufferDesc.dwBufferBytes = 65536;
    bufferDesc.lpwfxFormat = &DAT_00546e60;
    DAT_00546e60.nChannels = 1;
    DAT_00546e60.nSamplesPerSec = sampleRate;
    DAT_00546e60.nAvgBytesPerSec = sampleRate * 2;
    DAT_00546e60.wBitsPerSample = 16;
    DAT_00546e60.nBlockAlign = 2;
    DAT_00546e60.wFormatTag = WAVE_FORMAT_PCM;

    gHResult1 = IDirectSound_CreateSoundBuffer(gDirectSound, &bufferDesc, &gSoundBuffers1[DAT_005a4f88[idx]], NULL);

    if (gHResult1 == DS_OK) {
        DAT_00574a00[DAT_005a4f88[idx]] = 1;
        DAT_0053ee00[DAT_005a4f88[idx]] = sampleRate;

        bufferDesc.dwSize = 36;
        bufferDesc.dwFlags = DSBCAPS_CTRLFREQUENCY | DSBCAPS_CTRLPAN | DSBCAPS_CTRLVOLUME;
        bufferDesc.dwBufferBytes = 65536;
        bufferDesc.lpwfxFormat = &DAT_00546e60;
        DAT_00546e60.nChannels = 1;
        DAT_00546e60.nSamplesPerSec = sampleRate;
        DAT_00546e60.nAvgBytesPerSec = sampleRate * 2;
        DAT_00546e60.wBitsPerSample = 16;
        DAT_00546e60.nBlockAlign = 2;
        DAT_00546e60.wFormatTag = WAVE_FORMAT_PCM;

        gHResult1 = IDirectSound_CreateSoundBuffer(gDirectSound, &bufferDesc, &gSoundBuffers2[DAT_005a4f88[idx]], NULL);
    }
}

void sound_func_004d2ca0(char *path, int dontStream, int idx) {
    byte *kvagBytes;
    int isStereo;
    unsigned int sampleRate;
    char temp[4];

    if (!gSoundSystemInitialized) {
        return;
    }

    free_audio_struct_buffer(idx);

    gSomeAudioStructs[idx].field0x0 = 0;

    if (gSoundBuffers1[DAT_005a4f88[idx]] != NULL) {
        gHResult1 = IDirectSoundBuffer_GetStatus(gSoundBuffers1[DAT_005a4f88[idx]], &sSoundStatus);

        if (gHResult1 == DS_OK) {
            IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[idx]]);
        }

        if (gSoundBuffers2[DAT_005a4f88[idx]] != NULL) {
            IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[idx]]);
        }
    } else {
        sound_func_004d2a10(idx, 22050, FALSE);
    }

    gSomeAudioStructs[idx].adpcmDataSize = get_data_file_length(path);

    if (dontStream != 0 && gSomeAudioStructs[idx].adpcmDataSize != 0) {
        if (gSomeAudioStructs[idx].kvagBytes != NULL) {
            custom_free(&gSomeAudioStructs[idx].kvagBytes);
        }

        kvagBytes = read_kvag_file(path);
        
        gSomeAudioStructs[idx].kvagBytes = kvagBytes;
        gSomeAudioStructs[idx].adpcmBytes = gSomeAudioStructs[idx].kvagBytes + KVAG_ADPCM_START;
        gSomeAudioStructs[idx].file = NULL;
        gSomeAudioStructs[idx].adpcmDataSize = KVAG_ADPCM_LENGTH(kvagBytes);
        
        sampleRate = KVAG_SAMPLE_RATE(kvagBytes);
        isStereo = KVAG_IS_STEREO(kvagBytes);
        
        sound_func_004d2a10(idx, sampleRate, isStereo);
        
        gSomeAudioStructs[idx].isStereo = isStereo;
    }

    if (gSomeAudioStructs[idx].adpcmDataSize != 0) {
        gSomeAudioStructs[idx].field0x14 = 65536;

        if (!dontStream) {
            gSomeAudioStructs[idx].file = open_data_file_relative(path, str_rb);
            fread(temp, 4, 1, gSomeAudioStructs[idx].file);

            if (temp[0] == 'K' && temp[1] == 'V' && temp[2] == 'A' && temp[3] == 'G') {
                fread(temp, 4, 1, gSomeAudioStructs[idx].file);
                gSomeAudioStructs[idx].adpcmDataSize = (temp[3] << 24) + (temp[2] << 16) + (temp[1] << 8) + temp[0];

                fread(temp, 4, 1, gSomeAudioStructs[idx].file);
                sampleRate = (temp[3] << 24) + (temp[2] << 16) + (temp[1] << 8) + temp[0];

                fread(temp, 2, 1, gSomeAudioStructs[idx].file);
                isStereo = (temp[1] << 8) + temp[0];

                sound_func_004d2a10(idx, sampleRate, isStereo + 1);
            } else {
                fseek(gSomeAudioStructs[idx].file, 0, SEEK_SET);
            }
        }

        IDirectSoundBuffer_SetCurrentPosition(gSoundBuffers1[DAT_005a4f88[idx]], 0);
        if (gSomeAudioStructs[idx].isStereo) {
            IDirectSoundBuffer_SetCurrentPosition(gSoundBuffers2[DAT_005a4f88[idx]], 0);
        }

        gSomeAudioStructs[idx].adpcmIndex1 = 0;
        gSomeAudioStructs[idx].adpcmPredictor1 = 0;
        gSomeAudioStructs[idx].adpcmIndex2 = 0;
        gSomeAudioStructs[idx].adpcmPredictor2 = 0;

        gSomeAudioStructs[idx].field0x138 = (gSomeAudioStructs[idx].isStereo + 1) * 8192;
        if (gSomeAudioStructs[idx].adpcmDataSize > gSomeAudioStructs[idx].field0x138) {
            DAT_0057137c = sound_func_004d26c0(idx, (short*)DAT_00546f80[idx], (short*)DAT_0051e3e0[idx], 8192);

            write_bytes_to_sound_buffer(gSoundBuffers1[DAT_005a4f88[idx]], DAT_00546f80[idx], 65536);
            if (gSomeAudioStructs[idx].isStereo) {
                write_bytes_to_sound_buffer(gSoundBuffers2[DAT_005a4f88[idx]], DAT_0051e3e0[idx], 65536);
            }

            gSomeAudioStructs[idx].field0xc = DAT_0057137c;
            gSomeAudioStructs[idx].field0x0 = 1;
            gSomeAudioStructs[idx].field0x4 = 3;
            gSomeAudioStructs[idx].field0x8 = 1;
        } else {
            memset(DAT_00546f80[idx], 0, 65536);

            DAT_0057137c = sound_func_004d26c0(idx, (short*)DAT_00546f80[idx], (short*)DAT_0051e3e0[idx], gSomeAudioStructs[idx].adpcmDataSize);

            write_bytes_to_sound_buffer(gSoundBuffers1[DAT_005a4f88[idx]], DAT_00546f80[idx], 65536);
            if (gSomeAudioStructs[idx].isStereo) {
                write_bytes_to_sound_buffer(gSoundBuffers2[DAT_005a4f88[idx]], DAT_0051e3e0[idx], 65536);
            }

            gSomeAudioStructs[idx].field0xc = DAT_0057137c;
            gSomeAudioStructs[idx].field0x0 = 1;
            gSomeAudioStructs[idx].field0x4 = 4;
            gSomeAudioStructs[idx].field0x8 = 0;
        }
    }
}

void sound_func_004d30e0(char *path, int dontStream, int idx) {
    byte *kvagBytes;
    int isStereo;
    unsigned int sampleRate;
    char temp[4];

    if (!gSoundSystemInitialized) {
        return;
    }

    kvagBytes = gSomeAudioStructs[idx].kvagBytes;

    if (path != NULL) {
        if (kvagBytes == NULL || strcmp(path, gSomeAudioStructs[idx].filePath) != 0) {
            free_audio_struct_buffer(idx);
            sound_func_004d2ca0(path, dontStream, idx);
            return;
        }
    }

    if (path != NULL) {
        sprintf(gSomeAudioStructs[idx].filePath, str_pct_s, path);
    }

    gSomeAudioStructs[idx].field0x0 = 0;

    if (gSoundBuffers1[DAT_005a4f88[idx]] != NULL) {
        gHResult1 = IDirectSoundBuffer_GetStatus(gSoundBuffers1[DAT_005a4f88[idx]], &sSoundStatus);

        if (gHResult1 == DS_OK) {
            IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[idx]]);
        }

        if (gSoundBuffers2[DAT_005a4f88[idx]] != NULL) {
            IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[idx]]);
        }
    } else {
        sound_func_004d2a10(idx, 22050, FALSE);
    }

    if (dontStream) {
        if (kvagBytes == NULL) {
            if (gSomeAudioStructs[idx].kvagBytes != NULL) {
                custom_free(&gSomeAudioStructs[idx].kvagBytes);
            }

            kvagBytes = read_kvag_file(path);

            sampleRate = KVAG_SAMPLE_RATE(kvagBytes);
            isStereo = KVAG_IS_STEREO(kvagBytes) + 1;

            sound_func_004d2a10(idx, sampleRate, isStereo);

            gSomeAudioStructs[idx].isStereo = isStereo;
        }

        gSomeAudioStructs[idx].kvagBytes = kvagBytes;
        gSomeAudioStructs[idx].adpcmBytes = gSomeAudioStructs[idx].kvagBytes + KVAG_ADPCM_START;
        gSomeAudioStructs[idx].file = NULL;
        gSomeAudioStructs[idx].adpcmDataSize = KVAG_ADPCM_LENGTH(kvagBytes);
    } else {
        gSomeAudioStructs[idx].adpcmDataSize = get_data_file_length(path);
    }

    if (gSomeAudioStructs[idx].adpcmDataSize != 0) {
        gSomeAudioStructs[idx].field0x14 = 65536;
        
        if (!dontStream) {
            gSomeAudioStructs[idx].file = open_data_file_relative(path, str_rb);
            fread(temp, 4, 1, gSomeAudioStructs[idx].file);

            if (temp[0] == 'K' && temp[1] == 'V' && temp[2] == 'A' && temp[3] == 'G') {
                fread(temp, 4, 1, gSomeAudioStructs[idx].file);
                gSomeAudioStructs[idx].adpcmDataSize = (temp[3] << 24) + (temp[2] << 16) + (temp[1] << 8) + temp[0];

                fread(temp, 4, 1, gSomeAudioStructs[idx].file);
                sampleRate = (temp[3] << 24) + (temp[2] << 16) + (temp[1] << 8) + temp[0];

                fread(temp, 2, 1, gSomeAudioStructs[idx].file);
                isStereo = (temp[1] << 8) + temp[0];

                sound_func_004d2a10(idx, sampleRate, isStereo + 1);
            } else {
                fseek(gSomeAudioStructs[idx].file, 0, SEEK_SET);
            }
        }

        IDirectSoundBuffer_SetCurrentPosition(gSoundBuffers1[DAT_005a4f88[idx]], 0);
        if (gSomeAudioStructs[idx].isStereo) {
            IDirectSoundBuffer_SetCurrentPosition(gSoundBuffers2[DAT_005a4f88[idx]], 0);
        }

        gSomeAudioStructs[idx].adpcmIndex1 = 0;
        gSomeAudioStructs[idx].adpcmPredictor1 = 0;
        gSomeAudioStructs[idx].adpcmIndex2 = 0;
        gSomeAudioStructs[idx].adpcmPredictor2 = 0;

        gSomeAudioStructs[idx].field0x138 = (gSomeAudioStructs[idx].isStereo + 1) * 8192;
        if (gSomeAudioStructs[idx].adpcmDataSize > gSomeAudioStructs[idx].field0x138) {
            DAT_0057137c = sound_func_004d26c0(idx, (short*)DAT_00546f80[idx], (short*)DAT_0051e3e0[idx], 8192);

            write_bytes_to_sound_buffer(gSoundBuffers1[DAT_005a4f88[idx]], DAT_00546f80[idx], 65536);
            if (gSomeAudioStructs[idx].isStereo) {
                write_bytes_to_sound_buffer(gSoundBuffers2[DAT_005a4f88[idx]], DAT_0051e3e0[idx], 65536);
            }

            gSomeAudioStructs[idx].field0xc = DAT_0057137c;
            gSomeAudioStructs[idx].field0x0 = 1;
            gSomeAudioStructs[idx].field0x4 = 3;
            gSomeAudioStructs[idx].field0x8 = 1;
        } else {
            memset(DAT_00546f80[idx], 0, 65536);

            DAT_0057137c = sound_func_004d26c0(idx, (short*)DAT_00546f80[idx], (short*)DAT_0051e3e0[idx], gSomeAudioStructs[idx].adpcmDataSize);

            write_bytes_to_sound_buffer(gSoundBuffers1[DAT_005a4f88[idx]], DAT_00546f80[idx], 65536);
            if (gSomeAudioStructs[idx].isStereo) {
                write_bytes_to_sound_buffer(gSoundBuffers2[DAT_005a4f88[idx]], DAT_0051e3e0[idx], 65536);
            }

            gSomeAudioStructs[idx].field0xc = DAT_0057137c;
            gSomeAudioStructs[idx].field0x0 = 1;
            gSomeAudioStructs[idx].field0x4 = 4;
            gSomeAudioStructs[idx].field0x8 = 0;
        }
    }
}

void sound_func_004d35a0(int idx) {
    DWORD playCursor;
    DWORD writeCursor;

    if (!gSoundSystemInitialized) {
        return;
    }

    if (gSomeAudioStructs[idx].field0x0 != 1) {
        return;
    }

    if (gSomeAudioStructs[idx].field0x4 == 3) {
        IDirectSoundBuffer_SetCurrentPosition(gSoundBuffers1[DAT_005a4f88[idx]], 0);
        if (gSomeAudioStructs[idx].isStereo) {
            IDirectSoundBuffer_SetCurrentPosition(gSoundBuffers2[DAT_005a4f88[idx]], 0);
        }

        play_sound_looping(DAT_005a4f88[idx]);
        gSomeAudioStructs[idx].field0x4 = 1;
        return;
    }

    if (gSomeAudioStructs[idx].field0x4 == 4) {
        IDirectSoundBuffer_SetCurrentPosition(gSoundBuffers1[DAT_005a4f88[idx]], 0);
        if (gSomeAudioStructs[idx].isStereo) {
            IDirectSoundBuffer_SetCurrentPosition(gSoundBuffers2[DAT_005a4f88[idx]], 0);
        }

        gSomeAudioStructs[idx].field0x4 = 0;
        gSomeAudioStructs[idx].field0x0 = 0;

        play_sound(DAT_005a4f88[idx]);

        if (gSomeAudioStructs[idx].file != NULL) {
            free_audio_struct_buffer(idx);
        }

        return;
    }

    IDirectSoundBuffer_GetCurrentPosition(gSoundBuffers1[DAT_005a4f88[idx]], &playCursor, &writeCursor);

    if (gSomeAudioStructs[idx].field0xc == gSomeAudioStructs[idx].adpcmDataSize &&
        ((gSomeAudioStructs[idx].field0x4 == 1 && playCursor >= gSomeAudioStructs[idx].field0x14 && playCursor < 0x8000) ||
            (gSomeAudioStructs[idx].field0x4 == 0 && playCursor >= gSomeAudioStructs[idx].field0x14 && playCursor >= 0x8000))
    ) {
        gSomeAudioStructs[idx].field0x0 = 0;
            
        IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[idx]]);
        if (gSoundBuffers2[DAT_005a4f88[idx]] != NULL) {
            IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[idx]]);
        }

        if (gSomeAudioStructs[idx].file != NULL) {
            free_audio_struct_buffer(idx);
        }

        return;
    }
    
    if (playCursor >= 0x8000) {
        if (gSomeAudioStructs[idx].field0x4 == 0) {
            if (gSomeAudioStructs[idx].field0x138 + gSomeAudioStructs[idx].field0xc < gSomeAudioStructs[idx].adpcmDataSize) {
                DAT_0057137c = sound_func_004d26c0(idx, (short*)DAT_00546f80[idx], (short*)DAT_0051e3e0[idx], 0x2000);
                gSomeAudioStructs[idx].field0xc += DAT_0057137c;
            } else {
                memset(DAT_00546f80[idx], 0, 0x8000);
                memset(DAT_0051e3e0[idx], 0, 0x8000);

                DAT_0057137c = sound_func_004d26c0(idx, (short*)DAT_00546f80[idx], (short*)DAT_0051e3e0[idx], 
                    gSomeAudioStructs[idx].adpcmDataSize - gSomeAudioStructs[idx].field0xc);

                gSomeAudioStructs[idx].field0x14 = gSomeAudioStructs[idx].adpcmDataSize - gSomeAudioStructs[idx].field0xc;
                gSomeAudioStructs[idx].field0xc = gSomeAudioStructs[idx].adpcmDataSize;
            }

            write_bytes_to_sound_buffer(gSoundBuffers1[DAT_005a4f88[idx]], DAT_00546f80[idx], 0x10000);
            if (gSomeAudioStructs[idx].isStereo) {
                write_bytes_to_sound_buffer(gSoundBuffers2[DAT_005a4f88[idx]], DAT_0051e3e0[idx], 0x10000);
            }

            gSomeAudioStructs[idx].field0x4 = 1;
        }
        
        return;
    }

    if (gSomeAudioStructs[idx].field0x4 == 1) {
        if (gSomeAudioStructs[idx].field0x138 + gSomeAudioStructs[idx].field0xc < gSomeAudioStructs[idx].adpcmDataSize) {
            DAT_0057137c = sound_func_004d26c0(idx, (short*)(DAT_00546f80[idx] + 0x8000), (short*)(DAT_0051e3e0[idx] + 0x8000), 0x2000);
            gSomeAudioStructs[idx].field0xc += DAT_0057137c;
        } else {
            memset(DAT_00546f80[idx] + 0x8000, 0, 0x8000);
            memset(DAT_0051e3e0[idx] + 0x8000, 0, 0x8000);

            DAT_0057137c = sound_func_004d26c0(idx, (short*)(DAT_00546f80[idx] + 0x8000), (short*)(DAT_0051e3e0[idx] + 0x8000), 
                gSomeAudioStructs[idx].adpcmDataSize - gSomeAudioStructs[idx].field0xc);
            
            gSomeAudioStructs[idx].field0x14 = (gSomeAudioStructs[idx].adpcmDataSize - gSomeAudioStructs[idx].field0xc) + 0x8000;
            gSomeAudioStructs[idx].field0xc = gSomeAudioStructs[idx].adpcmDataSize;
        }

        write_bytes_to_sound_buffer(gSoundBuffers1[DAT_005a4f88[idx]], DAT_00546f80[idx], 0x10000);
        if (gSomeAudioStructs[idx].isStereo) {
            write_bytes_to_sound_buffer(gSoundBuffers2[DAT_005a4f88[idx]], DAT_0051e3e0[idx], 0x10000);
        }

        gSomeAudioStructs[idx].field0x4 = 0;
        return;
    }
}

void sound_func_004d39a0(byte *kvagBytes, int idx, int volume1, int volume2, int pitch, int playLooping) {
    unsigned int adpcmByteLength;
    unsigned int sampleRate;
    int isStereo;
    DSBUFFERDESC bufferDesc = {0};

    if (!gSoundSystemInitialized) {
        return;
    }

    if (!handle_window_focus_change()) {
        return;
    }

    if (is_sound_playing(idx)) {
        return;
    }

    if (DAT_00574a00[idx] != 0) {
        release_sound_buffers(idx);
    }

    memset(&bufferDesc, 0, sizeof(bufferDesc));

    gADPCMPredictor = 0;
    gADPCMIndex = 0;
    gADPCMPredictor2 = 0;
    gADPCMIndex2 = 0;

    adpcmByteLength = KVAG_ADPCM_LENGTH(kvagBytes);
    sampleRate = KVAG_SAMPLE_RATE(kvagBytes);
    isStereo = KVAG_IS_STEREO(kvagBytes);

    if (sampleRate == 0) {
        sampleRate = 11025;
    }

    bufferDesc.dwSize = 36;
    bufferDesc.dwFlags = DSBCAPS_CTRLFREQUENCY | DSBCAPS_CTRLPAN | DSBCAPS_CTRLVOLUME;
    bufferDesc.dwBufferBytes = isStereo ? adpcmByteLength * 2 : adpcmByteLength * 4;
    bufferDesc.lpwfxFormat = &DAT_00546e60;

    DAT_00546e60.nChannels = 1;
    DAT_00546e60.nSamplesPerSec = sampleRate;
    DAT_00546e60.nAvgBytesPerSec = DAT_00546e60.nSamplesPerSec * 2;
    DAT_00546e60.wBitsPerSample = 16;
    DAT_00546e60.nBlockAlign = 2;
    DAT_00546e60.wFormatTag = WAVE_FORMAT_PCM;

    gHResult2 = DS_OK;

    gSoundBuffers1[idx] = NULL;
    gSoundBuffers2[idx] = NULL;

    gHResult1 = IDirectSound_CreateSoundBuffer(gDirectSound, &bufferDesc, &gSoundBuffers1[idx], NULL);
    if (isStereo) {
        gHResult2 = IDirectSound_CreateSoundBuffer(gDirectSound, &bufferDesc, &gSoundBuffers2[idx], NULL);
    }

    if (gHResult1 == DS_OK && gHResult2 == DS_OK) {
        write_adpcm_to_sound_buffers(
            gSoundBuffers1[idx], 
            gSoundBuffers2[idx], 
            kvagBytes + KVAG_ADPCM_START, 
            adpcmByteLength * 4, 
            isStereo);
        
        DAT_00574a00[idx] = 2;
        DAT_0053ee00[idx] = DAT_00546e60.nSamplesPerSec;

        sound_set_pan_1(volume1, volume2, idx);
        sound_set_volume_1(volume1, volume2, idx);
        sound_set_pitch(pitch, idx);

        if (playLooping) {
            play_sound_looping(idx);
        } else {
            play_sound(idx);
        }
    }
}

unsigned int sound_func_004d3be0() {
    unsigned int ret;
    int i;
    
    if (!gSoundSystemInitialized) {
        return 0;
    }

    ret = 0;

    for (i = 0; i < 2; i++) {
        if (gSoundBuffers1[DAT_005a4f88[i]] != NULL && gSomeAudioStructs[i].field0x0 != 0) {
            ret |= 1 << i;
        }

        if (gSoundBuffers1[DAT_005a4f88[i]] != NULL && gSomeAudioStructs[i].file != NULL) {
            ret |= 1 << i; 
        }

        if (gSoundBuffers1[DAT_005a4f88[i]] != NULL) {
            gHResult1 = IDirectSoundBuffer_GetStatus(gSoundBuffers1[DAT_005a4f88[i]], &sSoundStatus);

            if (gSomeAudioStructs[i].field0x0 != 0 && (sSoundStatus & DSBSTATUS_PLAYING) == DSBSTATUS_PLAYING) {
                ret |= 1 << i;
            }
        }
    }

    return ret;
}

void sound_func_004d3c80() {
    int i;

    if (!gSoundSystemInitialized) {
        return;
    }

    for (i = 0; i < 2; i++) {
        if (gSomeAudioStructs[i].field0x0 == 2) {
            continue;
        }

        sSoundBuffer1 = gSoundBuffers1[DAT_005a4f88[i]];
        sSoundBuffer2 = gSoundBuffers2[DAT_005a4f88[i]];

        if (sSoundBuffer1 != NULL) {
            gHResult1 = IDirectSoundBuffer_GetStatus(sSoundBuffer1, &sSoundStatus);
            
            if (gSomeAudioStructs[i].field0x0 != 0 && (sSoundStatus & DSBSTATUS_PLAYING) == DSBSTATUS_PLAYING) {
                gSomeAudioStructs[i].field0x0 = 2;

                IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[i]]);
                if (sSoundBuffer2 != NULL) {
                    IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[i]]);
                }   
            }
        }
    }
}

void sound_func_004d3d30(int idx) {
    if (!gSoundSystemInitialized) {
        return;
    }

    if (gSomeAudioStructs[idx].field0x0 == 2) {
        return;
    }

    sSoundBuffer1 = gSoundBuffers1[DAT_005a4f88[idx]];
    sSoundBuffer2 = gSoundBuffers2[DAT_005a4f88[idx]];

    if (sSoundBuffer1 != NULL) {
        gHResult1 = IDirectSoundBuffer_GetStatus(sSoundBuffer1, &sSoundStatus);
        
        if (gSomeAudioStructs[idx].field0x0 != 0 && (sSoundStatus & DSBSTATUS_PLAYING) == DSBSTATUS_PLAYING) {
            gSomeAudioStructs[idx].field0x0 = 2;

            IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[idx]]);
            if (sSoundBuffer2 != NULL) {
                IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[idx]]);
            }   
        }
    }
}

void sound_func_004d3df0() {
    int i;

    if (!gSoundSystemInitialized) {
        return;
    }

    for (i = 0; i < 2; i++) {
        if (gSomeAudioStructs[i].field0x0 != 2) {
            continue;
        }

        sSoundBuffer1 = gSoundBuffers1[DAT_005a4f88[i]];
        sSoundBuffer2 = gSoundBuffers2[DAT_005a4f88[i]];

        if (sSoundBuffer1 != NULL) {
            gSomeAudioStructs[i].field0x0 = 1;
            
            if (gSomeAudioStructs[i].field0x8 != 0) {
                gHResult1 = IDirectSoundBuffer_Play(sSoundBuffer1, 0, 0, DSBPLAY_LOOPING);
                if (sSoundBuffer2 != NULL) {
                    IDirectSoundBuffer_Play(sSoundBuffer2, 0, 0, DSBPLAY_LOOPING);
                }
            } else {
                gSomeAudioStructs[i].field0x0 = 0;

                gHResult1 = IDirectSoundBuffer_Play(sSoundBuffer1, 0, 0, 0);
                if (sSoundBuffer2 != NULL) {
                    IDirectSoundBuffer_Play(sSoundBuffer2, 0, 0, 0);
                }
            }
        }
    }
}

void sound_func_004d3ea0(int idx) {
    if (!gSoundSystemInitialized) {
        return;
    }

    if (gSomeAudioStructs[idx].field0x0 != 2) {
        return;
    }

    sSoundBuffer1 = gSoundBuffers1[DAT_005a4f88[idx]];
    sSoundBuffer2 = gSoundBuffers2[DAT_005a4f88[idx]];

    if (sSoundBuffer1 != NULL) {
        gSomeAudioStructs[idx].field0x0 = 1;
        
        if (gSomeAudioStructs[idx].field0x8 != 0) {
            gHResult1 = IDirectSoundBuffer_Play(sSoundBuffer1, 0, 0, DSBPLAY_LOOPING);
            if (sSoundBuffer2 != NULL) {
                IDirectSoundBuffer_Play(sSoundBuffer2, 0, 0, DSBPLAY_LOOPING);
            }
        } else {
            gSomeAudioStructs[idx].field0x0 = 0;

            gHResult1 = IDirectSoundBuffer_Play(sSoundBuffer1, 0, 0, 0);
            if (sSoundBuffer2 != NULL) {
                IDirectSoundBuffer_Play(sSoundBuffer2, 0, 0, 0);
            }
        }
    }
}

void sound_func_004d3f60() {
    int i;

    if (!gSoundSystemInitialized) {
        return;
    }

    for (i = 0; i < 2; i++) {
        if (gSomeAudioStructs[i].field0x0 == 0) {
            continue;
        }

        if (gSoundBuffers1[DAT_005a4f88[i]] != NULL) {
            IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[i]]);

            if (gSomeAudioStructs[i].isStereo) {
                IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[i]]);
            }
        }

        DAT_00574a00[DAT_005a4f88[i]] = 0;
        free_audio_struct_buffer(i);

        gSomeAudioStructs[i].field0x0 = 0;
    }
}

void sound_func_004d3fe0(int idx) {
    if (!gSoundSystemInitialized) {
        return;
    }

    if (gSomeAudioStructs[idx].field0x0 == 0) {
        return;
    }

    if (gSoundBuffers1[DAT_005a4f88[idx]] != NULL) {
        IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[idx]]);

        if (gSomeAudioStructs[idx].isStereo) {
            IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[idx]]);
        }
    }

    DAT_00574a00[DAT_005a4f88[idx]] = 0;
    free_audio_struct_buffer(idx);

    gSomeAudioStructs[idx].field0x0 = 0;
}

void sound_func_004d4060() {
    int i;

    if (!gSoundSystemInitialized) {
        return;
    }

    for (i = 0; i < 16; i++) {
        if (DAT_00574a00[i] != 0) {
            release_sound_buffers(i);
        }
    }
}

void sound_func_004d4090() {
    int i;

    if (!gSoundSystemInitialized) {
        return;
    }

    for (i = 0; i < 2; i++) {
        if (gSoundBuffers1[DAT_005a4f88[i]] != NULL) {
            IDirectSoundBuffer_Stop(gSoundBuffers1[DAT_005a4f88[i]]);
            IDirectSoundBuffer_Release(gSoundBuffers1[DAT_005a4f88[i]]);

            if (gSoundBuffers2[DAT_005a4f88[i]] != NULL) {
                IDirectSoundBuffer_Stop(gSoundBuffers2[DAT_005a4f88[i]]);
                IDirectSoundBuffer_Release(gSoundBuffers2[DAT_005a4f88[i]]);
            }

            gSoundBuffers1[DAT_005a4f88[i]] = NULL;
            gSoundBuffers2[DAT_005a4f88[i]] = NULL;
        }

        DAT_00574a00[DAT_005a4f88[i]] = 0;
        free_audio_struct_buffer(i);

        gSomeAudioStructs[i].field0x0 = 0;
    }
}

void free_audio_struct_buffer(int idx) {
    if (!gSoundSystemInitialized) {
        return;
    }

    if (gSomeAudioStructs[idx].file != NULL) {
        // Close file
        fclose(gSomeAudioStructs[idx].file);
        gSomeAudioStructs[idx].file = NULL;
    } else if (gSomeAudioStructs[idx].kvagBytes != NULL) {
        // Free KVAG byte buffer
        custom_free(&gSomeAudioStructs[idx].kvagBytes);
        gSomeAudioStructs[idx].kvagBytes = NULL;
    }
}

/*
param1  param2 pan
0       0       0
0       1       -10000 (full pan left)
1       0       10000 (full pan right)
1       2       -2000
2       1       2000
10      10      0
*/
void sound_set_pan_1(int param1, int param2, int idx) {
    int pan;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    pan = 0;
    
    if (param2 != 0 && param1 != 0 && param2 > param1) {
        pan = (param1 * 100) / param2;
        if (pan != 0) {
            pan = -100000 / pan;
        } else {
            pan = DSBPAN_LEFT;
        }
    } else if (param1 != 0 && param2 != 0 && param1 > param2) {
        pan = (param2 * 100) / param1;
        if (pan != 0) {
            pan = 100000 / pan;
        } else {
            pan = DSBPAN_RIGHT;
        }
    } else if (param2 == param1) {
        pan = 0;
    } else if (param2 == 0) {
        pan = DSBPAN_RIGHT;
    } else if (param1 == 0) {
        pan = DSBPAN_LEFT;
    }

    if (DAT_00574a00[idx] != 0) {
        sSoundBuffer1 = gSoundBuffers1[idx];
        sSoundBuffer2 = gSoundBuffers2[idx];

        if (sSoundBuffer2 != NULL) {
            IDirectSoundBuffer_SetPan(sSoundBuffer1, pan + 1000);
            IDirectSoundBuffer_SetPan(sSoundBuffer2, pan - 1000);
        } else {
            IDirectSoundBuffer_SetPan(sSoundBuffer1, pan);
        }
    }
}

void sound_set_pan_2(int param1, int param2, int idx) {
    int pan;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    pan = 0;
    
    if (param2 != 0 && param1 != 0 && param2 > param1) {
        pan = (param1 * 100) / param2;
        if (pan != 0) {
            pan = -100000 / pan;
        } else {
            pan = DSBPAN_LEFT;
        }
    } else if (param1 != 0 && param2 != 0 && param1 > param2) {
        pan = (param2 * 100) / param1;
        if (pan != 0) {
            pan = 100000 / pan;
        } else {
            pan = DSBPAN_RIGHT;
        }
    } else if (param2 == param1) {
        pan = 0;
    } else if (param2 == 0) {
        pan = DSBPAN_RIGHT;
    } else if (param1 == 0) {
        pan = DSBPAN_LEFT;
    }

    if (DAT_00574a00[DAT_005a4f88[idx]] != 0) {
        sSoundBuffer1 = gSoundBuffers1[DAT_005a4f88[idx]];
        sSoundBuffer2 = gSoundBuffers2[DAT_005a4f88[idx]];

        if (sSoundBuffer2 != NULL && gSomeAudioStructs[idx].isStereo) {
            IDirectSoundBuffer_SetPan(sSoundBuffer1, pan + 1000);
            IDirectSoundBuffer_SetPan(sSoundBuffer2, pan - 1000);
        } else {
            IDirectSoundBuffer_SetPan(sSoundBuffer1, pan);
        }
    }
}

/*
    Converts a value in the range [0,16384] to the range [-10000,0] (hundredths of decibels).

    val     -> ret
    0       -> -10000
    8192    -> -5000
    16384   -> 0
*/
int convert_value_to_volume(int val) {
    int ret;
    
    if (!gSoundSystemInitialized) {
        return; // another missing return value...
    }

    // linear conversion
    ret = ((16384 - val) * (10000/4)) / (16384/4);

    if (ret >= 10000) {
        ret = 9998;
    }

    return -ret;
}

void sound_set_volume_1(int param1, int param2, int idx) {
    int volume;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    if (param1 >= param2) {
        volume = convert_value_to_volume(param1);
    } else {
        volume = convert_value_to_volume(param2);
    }
    
    if (DAT_00574a00[idx] != 0) {
        sSoundBuffer1 = gSoundBuffers1[idx];
        sSoundBuffer2 = gSoundBuffers2[idx];

        IDirectSoundBuffer_SetVolume(sSoundBuffer1, volume);
        if (sSoundBuffer2 != NULL) {
            IDirectSoundBuffer_SetVolume(sSoundBuffer2, volume);
        }
    }
}

void sound_set_volume_2(int param1, int param2, int idx) {
    int volume;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    volume = convert_value_to_volume((param1 + param2) / 2);
    
    if (DAT_00574a00[DAT_005a4f88[idx]] != 0) {
        sSoundBuffer1 = gSoundBuffers1[DAT_005a4f88[idx]];
        sSoundBuffer2 = gSoundBuffers2[DAT_005a4f88[idx]];

        IDirectSoundBuffer_SetVolume(sSoundBuffer1, volume);
        if (sSoundBuffer2 != NULL) {
            IDirectSoundBuffer_SetVolume(sSoundBuffer2, volume);
        }
    }
}

// NOTE: This actually matches! However, the double literal gets compiled into
// the .rdata section and referencing that address via an extern generates different
// code... We don't have a way to deal with this at the moment. :(
#ifdef NON_EQUIVALENT
void sound_set_pitch(int pitch, int idx) {
    unsigned int frequency;
    
    if (!gSoundSystemInitialized) {
        return;
    }

    frequency = (pitch / 1024.0) * DAT_0053ee00[idx];

    if (DAT_00574a00[idx] != 0) {
        sSoundBuffer1 = gSoundBuffers1[idx];
        sSoundBuffer2 = gSoundBuffers2[idx];

        IDirectSoundBuffer_SetFrequency(sSoundBuffer1, frequency);
        if (sSoundBuffer2 != NULL) {
            IDirectSoundBuffer_SetFrequency(sSoundBuffer2, frequency);
        }
    }
}
#else
#pragma ASM_FUNC sound_set_pitch
#endif
