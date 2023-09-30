#pragma once

// A file for all global/static and function definitions that don't have
// a home in a specific segment file. All definitions here should be extern.

#include <WINDOWS.H>

extern char gTempString[];
extern char gTempString2[];

extern int gLaunchWindowed;

extern int gCursorTextures;
extern int gWindowFocused;

extern int DAT_00ece464;
extern int DAT_00945e94;
extern int DAT_00f0c770;
extern int DAT_01359b80;

extern void FUN_004d8010(int);
extern void load_cursor_textures();

extern void display_message(char *format, ...);
extern void display_message_and_exit(char* message);
extern void game_exit();

extern int handle_window_focus_change();
extern int check_window_focus_change(int);

extern int set_cursor_pos(int x, int y);
