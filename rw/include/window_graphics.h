#pragma once

#include <WINDEF.h>

#include "types.h"

extern int32 gDisplayWidth;
extern int32 gDisplayHeight;

extern bool gBitmapCreated;
extern uint16 *gInMemoryGraphicsSurface;

extern uint16 g16BitColorPallete[65536];

extern int32 DAT_0051b978;

extern const char *get_last_graphics_error_reason();

extern bool set_cursor_pos(int32 x, int32 y);

extern bool some_graphics_init(int32 width, int32 height, int32 bpp);
extern void do_window_paint(HWND hWnd);
extern bool init_directx(int32 displayWidth, int32 displayHeight, int32 displayBpp);
extern void free_graphics_stuff();

extern void clear_surface(LPDIRECTDRAWSURFACE4 surface, uint32 color);
extern void clear_in_memory_graphics_surface();

extern void draw_frame();
