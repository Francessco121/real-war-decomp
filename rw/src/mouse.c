#include <WINDOWS.H>

#include "mouse.h"
#include "types.h"
#include "undefined.h"
#include "warnsuppress.h"
#include "window.h"

#define MOUSE_HISTORY_LEN 5

// .bss

// Unbuffered inputs

uint32 gPrevMouseButtonsHeldUnbuffered;
uint32 gMouseButtonsHeldUnbuffered;
int32 gCursorUnbufferedX;
int32 gCursorUnbufferedY;
int32 gCurrentScrollWheelDelta;

// Buffering history

int32 gMouseHistoryIdx;
int32 gMouseBufferIdx;
uint32 gMouseButtonHistory[MOUSE_HISTORY_LEN];
int32 gMouseXHistory[MOUSE_HISTORY_LEN];
int32 gMouseYHistory[MOUSE_HISTORY_LEN];

// Current buffered inputs (this frame)

uint32 gMouseButtonsHeld;
int32 gScrollWheelDelta;
int32 gCursorX;
int32 gCursorY;
int32 gMouseButtonsClicked;

// Unused

int32 gUnusedMouseGlobal1;
int32 gUnusedMouseGlobal2;

// .text

void mouse_init() {
    MSG msg;

    set_cursor_pos(gCursorX, gCursorY);
    check_window_focus_change(0);

    while (PeekMessageA(&msg, NULL, 0, 0, PM_NOREMOVE)) {
        GetMessageA(&msg, NULL, 0, 0);
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }

    gMouseHistoryIdx = 0;
    gMouseBufferIdx = 0;
    gMouseButtonsHeldUnbuffered = 0;
    gPrevMouseButtonsHeldUnbuffered = 0;
    gMouseButtonsClicked = 0;
    gUnusedMouseGlobal1 = 0;
    gUnusedMouseGlobal2 = 0;
    gCursorX = 320;
    gCursorY = 240;
}

__inline static void _add_mouse_history_entry() {
    if (gMouseButtonsHeldUnbuffered != gMouseButtonHistory[(gMouseHistoryIdx - 1) % MOUSE_HISTORY_LEN]) {
        gMouseButtonHistory[gMouseHistoryIdx] = gMouseButtonsHeldUnbuffered;
        gMouseXHistory[gMouseHistoryIdx] = gCursorUnbufferedX;
        gMouseYHistory[gMouseHistoryIdx] = gCursorUnbufferedY;

        gMouseHistoryIdx += 1;

        if (gMouseHistoryIdx >= MOUSE_HISTORY_LEN) {
            gMouseHistoryIdx = 0;
        }
    }
}

void handle_mouse_move(HWND hWnd, int32 mouseX, int32 mouseY, uint32 modifiers) {
    if (!handle_window_focus_change()) {
        return;
    }

    gCursorUnbufferedX = mouseX;
    gCursorUnbufferedY = mouseY;

    if (modifiers & MK_LBUTTON) {
        gMouseButtonsHeldUnbuffered = gMouseButtonsHeldUnbuffered | MOUSE_BUTTON_LEFT;
    } else {
        gMouseButtonsHeldUnbuffered = gMouseButtonsHeldUnbuffered & ~MOUSE_BUTTON_LEFT;
    }

    if (modifiers & MK_RBUTTON) {
        gMouseButtonsHeldUnbuffered = gMouseButtonsHeldUnbuffered | MOUSE_BUTTON_RIGHT;
    } else {
        gMouseButtonsHeldUnbuffered = gMouseButtonsHeldUnbuffered & ~MOUSE_BUTTON_RIGHT;
    }

    _add_mouse_history_entry();
}

void handle_m1_down(HWND hWnd, int32 param2, int32 mouseX, int32 mouseY, uint32 modifiers) {
    if (!handle_window_focus_change()) {
        return;
    }

    gMouseButtonsHeldUnbuffered |= MOUSE_BUTTON_LEFT;

    _add_mouse_history_entry();
}

void handle_m1_up(HWND hWnd, int32 mouseX, int32 mouseY, uint32 modifiers) {
    if (!handle_window_focus_change()) {
        return;
    }

    gMouseButtonsHeldUnbuffered &= ~MOUSE_BUTTON_LEFT;

    _add_mouse_history_entry();
}

void handle_m2_down(HWND hWnd, int32 param2, int32 mouseX, int32 mouseY, uint32 modifiers) {
    if (!handle_window_focus_change()) {
        return;
    }

    gMouseButtonsHeldUnbuffered |= MOUSE_BUTTON_RIGHT;

    _add_mouse_history_entry();
}

void handle_m2_up(HWND hWnd, int32 mouseX, int32 mouseY, uint32 modifiers) {
    if (!handle_window_focus_change()) {
        return;
    }

    gMouseButtonsHeldUnbuffered &= ~MOUSE_BUTTON_RIGHT;

    _add_mouse_history_entry();
}

void update_mouse_state() {
    uint32 prevButtonsHeld;
    
    // Get scroll wheel delta for this frame
    gScrollWheelDelta = 0;
    if (gCurrentScrollWheelDelta != 0) {
        gScrollWheelDelta = gCurrentScrollWheelDelta;
    }
    gCurrentScrollWheelDelta = 0;

    // Save previous buttons held
    prevButtonsHeld = gMouseButtonsHeld;
    gPrevMouseButtonsHeldUnbuffered = prevButtonsHeld;
    
    if (gMouseBufferIdx != gMouseHistoryIdx) {
        // Replay buffered mouse inputs until we catch up
        gCursorX = gMouseXHistory[gMouseBufferIdx];
        gCursorY = gMouseYHistory[gMouseBufferIdx];
        gMouseButtonsHeld = gMouseButtonHistory[gMouseBufferIdx];

        gMouseBufferIdx += 1;
        if (gMouseBufferIdx >= 5) {
            gMouseBufferIdx = 0;
        }
    } else {
        // No buffered inputs to take, use the current mouse inputs
        gCursorX = gCursorUnbufferedX;
        gCursorY = gCursorUnbufferedY;
        gMouseButtonsHeld = gMouseButtonsHeldUnbuffered;
    }

    // Calculate which buttons were pressed initially on this frame
    gMouseButtonsClicked = (gMouseButtonsHeld ^ prevButtonsHeld) & gMouseButtonsHeld;
}

bool mouse_btns_held_in_rect(int32 left, int32 top, int32 right, int32 bottom, uint32 buttons) {
    bool ret;
    
    if (!handle_window_focus_change()) {
        return FALSE;
    }

    ret = FALSE;

    if (gCursorX >= left && 
        gCursorX <= right && 
        gCursorY >= top && 
        gCursorY <= bottom && 
        gMouseButtonsHeld & buttons
    ) {
        ret = TRUE;
    }

    return ret;
}

bool mouse_btns_clicked_in_rect(int32 left, int32 top, int32 right, int32 bottom, uint32 buttons) {
    bool ret;
    
    if (!handle_window_focus_change()) {
        return FALSE;
    }

    ret = FALSE;

    if (gCursorX >= left && 
        gCursorX <= right && 
        gCursorY >= top && 
        gCursorY <= bottom && 
        gMouseButtonsClicked & buttons
    ) {
        ret = TRUE;
    }

    return ret;
}

int32 force_mouse_btns_clicked(uint32 buttons) {
    if (handle_window_focus_change()) {
        gMouseButtonsClicked |= buttons;
    }

    return 0;
}

int32 force_mouse_btns_held(uint32 buttons) {
    if (handle_window_focus_change()) {
        gMouseButtonsHeld |= buttons;
    }

    return 0;
}

bool is_cursor_in_rect(int32 left, int32 top, int32 right, int32 bottom) {
    bool ret;

    ret = handle_window_focus_change();
    
    if (ret) {
        ret = FALSE;

        if (gCursorX >= left && 
            gCursorX <= right && 
            gCursorY >= top && 
            gCursorY <= bottom
        ) {
            ret = TRUE;
        }
    }

    return ret;
}
