#pragma once

// A file for all global/static and function definitions that don't have
// a home in a specific segment file. All definitions here should be extern.

#include <DDRAW.h>

#include "types.h"

extern char gTempString[];
extern char gTempString2[];

extern int gCursorTextures;

extern int32 DAT_00ece464;
extern int32 DAT_00945e94;
extern int32 DAT_00f0c770;
extern int32 DAT_01359b80;

extern int32 DAT_0051b418;
extern float32 DAT_01b18068;

extern int32 gDontReleaseDirectDraw;

extern LPDIRECTDRAWSURFACE gDDFrontBuffer;
extern LPDIRECTDRAWSURFACE gDDBackBuffer;
extern LPDIRECTDRAW4 gDirectDraw4;

extern int32 gD3DDeviceFound;

extern bool gBitmapCreated;

extern int gLaunchWindowed;
extern char gCmdLineArgN[];
extern int32 gCmdLineArgM;
extern int32 gCmdLineArgT;
extern int32 gCmdLineArgC;
extern int32 gCmdLineArgL;
extern int32 gCmdLineArgE;
extern int32 gCmdLineArgB;
extern int32 gCmdLineArgS;
extern char gCmdLineArgP[];
extern int32 gCmdLineArgF;
extern int32 gCmdLineArgH;

extern const GUID *LPCGUID_005a4f84;
extern GUID GUID_004ea6c8;

extern bool FUN_00401100(HWND hWnd);

extern void FUN_004d8010(int32);
extern void load_cursor_textures();

extern int check_window_focus_change(int32);

extern int set_cursor_pos(int32 x, int32 y);

extern void game_main();

extern void FUN_004a5c30();
extern void FUN_0047a020();
extern void FUN_004c8ab0();
extern void FUN_00401b40();

extern void free_graphics_stuff();
extern void do_window_paint(HWND hWnd);

extern int32 get_memory_in_use_bytes(char *str);
