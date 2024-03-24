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

extern LPDIRECTDRAWSURFACE4 gDDFrontBuffer;
extern LPDIRECTDRAWSURFACE4 gDDBackBuffer;
extern LPDIRECTDRAW4 gDirectDraw4;

extern int32 gD3DDeviceFound;

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

extern int32 DAT_00fe04d0;
extern int32 DAT_0051b7f4;

extern int32 DAT_00567aa0;
extern int32 DAT_0051add4;
extern bool gDontInitD3D;
extern int32 DAT_0051b8e0;

extern int32 DAT_0051b960;
extern int32 DAT_0051b90c;

extern bool FUN_00401100(HWND hWnd);

extern void FUN_004d8010(int32);
extern void load_cursor_textures();
extern void free_all_cursor_textures();

extern int check_window_focus_change(int32);

extern void game_main();

extern void FUN_004a5c30();
extern void FUN_0047a020();
extern void FUN_004c8ab0();
extern void FUN_00401b40();

extern int32 get_memory_in_use_bytes(char *str);

extern void FUN_00406e60();
extern int32 get_available_vid_memory();
extern bool init_d3d(HWND);
extern int32 FUN_004013f0(HWND);
extern void FUN_00406ed0();
extern void FUN_0041a8e0();
extern void FUN_00401870(HWND);

extern void memcpy_dword(uint32 *dst, uint32 *src, size_t count);
extern void memset_dword(uint32 *dst, uint32 value, size_t count);
extern void memset_word(uint16 *dst, uint16 value, size_t count);

extern void FUN_004d7bc0();
extern void FUN_0041a830();
extern void FUN_004d7d60();
extern void FUN_00406fc0();
extern void FUN_00401b90(int32);
extern void FUN_00406f30();

extern void FUN_004c3b60(int32*, int32*, int32*, int32*, int32*);
extern void FUN_004c3ac0(int32, int32, int32, int32);
extern void FUN_004c39f0(const char *str, int32 x, int32 y);
