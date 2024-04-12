#pragma once

#include <WINDEF.H>

extern HWND gWndHandle;
extern bool32 gWindowFocused;

extern bool32 FUN_004d45b0();

extern void game_exit();

extern void display_messagebox(const char *format, ...);
extern void display_messagebox_and_exit(const char* message);
extern bool32 display_yesno_messagebox(const char *message);

extern int32 get_next_buffered_key();
extern void reset_keydown_buffer();

extern void pump_messages_and_update_input_state();
extern void pump_messages();
extern bool32 handle_window_focus_change();
