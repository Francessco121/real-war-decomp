#pragma once

// A file for all global/static and function definitions that don't have
// a home in a specific segment file. All definitions here should be extern.

#include "types.h"

extern char gTempString[];
extern char gTempString2[];

extern int gLaunchWindowed;

extern int gCursorTextures;
extern bool gWindowFocused;

extern int32 DAT_00ece464;
extern int32 DAT_00945e94;
extern int32 DAT_00f0c770;
extern int32 DAT_01359b80;

extern void FUN_004d8010(int32);
extern void load_cursor_textures();

extern void display_message(const char *format, ...);
extern void display_message_and_exit(const char* message);
extern int game_exit();

extern int handle_window_focus_change();
extern int check_window_focus_change(int32);

extern int set_cursor_pos(int32 x, int32 y);

extern void game_main();
