#pragma once

#include "types.h"

extern void init_sound_system();
extern void deinit_sound_system();

extern void sound_func_004d1d90();
extern void sound_func_004d1e60(int32 idx);
extern bool32 is_sound_playing(int32 idx);
/**
 * Reads KVAG bytes from a file.
 * 
 * The file can either be raw ADPCM bytes or a KVAG container.
 * If the file is just raw ADPCM, a header will be added to the returned bytes.
 */
extern uint8* read_kvag_file(const char* filePath);
extern void sound_func_004d2a10(int32 idx, uint32 sampleRate, int32 channels);
extern void sound_func_004d2ca0(const char *path, bool32 dontStream, int32 idx);
extern void sound_func_004d30e0(const char *path, bool32 dontStream, int32 idx);
extern void sound_func_004d39a0(const uint8 *kvagBytes, int32 idx, int32 volume1, int32 volume2, int32 pitch, bool32 playLooping);
extern uint32 sound_func_004d3be0();
extern void sound_func_004d3c80();
extern void sound_func_004d3d30(int32 idx);
extern void sound_func_004d3df0();
extern void sound_func_004d3ea0(int32 idx);
extern void sound_func_004d3f60();
extern void sound_func_004d3fe0(int32 idx);
extern void sound_func_004d4060();
extern void sound_set_pan_1(int32 param1, int32 param2, int32 idx);
extern void sound_set_pan_2(int32 param1, int32 param2, int32 idx);
extern void sound_set_volume_1(int32 param1, int32 param2, int32 idx);
extern void sound_set_volume_2(int32 param1, int32 param2, int32 idx);
