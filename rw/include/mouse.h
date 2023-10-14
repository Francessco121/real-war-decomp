#pragma once

#include "types.h"

#define MOUSE_BUTTON_LEFT 0x1
#define MOUSE_BUTTON_RIGHT 0x2

extern int32 gCursorUnbufferedX;
extern int32 gCursorUnbufferedY;
extern int32 gCursorX;
extern int32 gCursorY;

/**
 * Mouse buttons that were pressed down on this frame
 * and were not held on the previous frame.
 * 
 * Bit 1 is set if the left mouse button was pressed.
 * Bit 2 is set if the right mouse button was pressed.
 */
extern int32 gMouseButtonsClicked;

void mouse_init();

void handle_mouse_move(HWND hWnd, int32 mouseX, int32 mouseY, int32 modifiers);
void handle_m1_down();
void handle_m1_up();
void handle_m2_down();
void handle_m2_up();

/**
 * Updates globals for the current mouse state (cursor position, buttons),
 * possibly from buffered inputs if any exist.
 */
void update_mouse_state();

bool mouse_btns_held_in_rect(int32 left, int32 top, int32 right, int32 bottom, uint32 buttons);
bool mouse_btns_clicked_in_rect(int32 left, int32 top, int32 right, int32 bottom, uint32 buttons);
int32 force_mouse_btns_clicked(uint32 buttons);
int32 force_mouse_btns_held(uint32 buttons);
bool is_cursor_in_rect(int32 left, int32 top, int32 right, int32 bottom);
