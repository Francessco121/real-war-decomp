#pragma once

#include <WINDOWS.H>

void init_sound_system();
void deinit_sound_system();

void sound_func_004d1d90();
void sound_func_004d1e60(int idx);
BOOL is_sound_playing(int idx);
/**
 * Reads KVAG bytes from a file.
 * 
 * The file can either be raw ADPCM bytes or a KVAG container.
 * If the file is just raw ADPCM, a header will be added to the returned bytes.
 */
BYTE* read_kvag_file(char* filePath);
void sound_func_004d2a10(int idx, unsigned int sampleRate, int channels);
void sound_func_004d2ca0(char *path, int dontStream, int idx);
void sound_func_004d30e0(char *path, int dontStream, int idx);
void sound_func_004d39a0(BYTE *kvagBytes, int idx, int volume1, int volume2, int pitch, int playLooping);
unsigned int sound_func_004d3be0();
void sound_func_004d3c80();
void sound_func_004d3d30(int idx);
void sound_func_004d3df0();
void sound_func_004d3ea0(int idx);
void sound_func_004d3f60();
void sound_func_004d3fe0(int idx);
void sound_func_004d4060();
void sound_set_pan_2(int param1, int param2, int idx);
void sound_set_volume_1(int param1, int param2, int idx);
void sound_set_volume_2(int param1, int param2, int idx);
