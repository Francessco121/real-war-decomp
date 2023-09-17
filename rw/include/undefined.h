#pragma once

// A file for all global/static and function definitions that don't have
// a home in a specific segment file. All definitions here should be extern.

#include <WINDOWS.H>

extern char gTempString[];
extern char gTempString2[];

extern int gLaunchWindowed;

extern int gCursorTextures;
extern int gWindowFocused;

extern void FUN_004d8010(int);
extern void load_cursor_textures();

extern void display_message(char *format, ...);
extern void display_message_and_exit(char* message);
extern void game_exit();

extern void to_absolute_data_path(char *path);
extern void to_absolute_data_path2(char *path);

