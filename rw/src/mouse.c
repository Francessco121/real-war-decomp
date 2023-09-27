#include "mouse.h"
#include "undefined.h"

#define MOUSE_HISTORY_LEN 5

// .bss

unsigned int gMouseButtonBits;
int gPrevMouseIdx;
int gSomeMouseHistoryIdx;
unsigned int gPrevMouseButtonBits[MOUSE_HISTORY_LEN];
int gPrevMouseXs[MOUSE_HISTORY_LEN];
int gPrevMouseYs[MOUSE_HISTORY_LEN];
unsigned int gSomeMoreMouseButtonBits;
unsigned int gSomeMouseButtonBits;
int gScrollWheelDelta;
int gPrevScrollWheelDelta;

int gUnusedMouseGlobal1;
int gUnusedMouseGlobal2;

// .text

void mouse_init() {
    MSG msg;

    set_cursor_pos(gCursorX2, gCursorY2);
    check_window_focus_change(0);

    while (PeekMessageA(&msg, NULL, 0, 0, PM_NOREMOVE)) {
        GetMessageA(&msg, NULL, 0, 0);
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }

    gPrevMouseIdx = 0;
    gSomeMouseHistoryIdx = 0;
    gMouseButtonBits = 0;
    gSomeMoreMouseButtonBits = 0;
    gUnkMouseButtonBits = 0;
    gUnusedMouseGlobal1 = 0;
    gUnusedMouseGlobal2 = 0;
    gCursorX2 = 320;
    gCursorY2 = 240;
}

__inline static void _add_mouse_history_entry() {
    if (gMouseButtonBits != gPrevMouseButtonBits[(gPrevMouseIdx - 1) % MOUSE_HISTORY_LEN]) {
        gPrevMouseButtonBits[gPrevMouseIdx] = gMouseButtonBits;
        gPrevMouseXs[gPrevMouseIdx] = gCursorX;
        gPrevMouseYs[gPrevMouseIdx] = gCursorY;
        gPrevMouseIdx += 1;

        if (gPrevMouseIdx >= MOUSE_HISTORY_LEN) {
            gPrevMouseIdx = 0;
        }
    }
}

void handle_mouse_move(HWND hWnd, int mouseX, int mouseY, int modifiers) {
    if (!handle_window_focus_change()) {
        return;
    }

    gCursorX = mouseX;
    gCursorY = mouseY;

    if (modifiers & MK_LBUTTON) {
        gMouseButtonBits = gMouseButtonBits | 1;
    } else {
        gMouseButtonBits = gMouseButtonBits & 0xfffffffe;
    }

    if (modifiers & MK_RBUTTON) {
        gMouseButtonBits = gMouseButtonBits | 2;
    } else {
        gMouseButtonBits = gMouseButtonBits & 0xfffffffd;
    }

    _add_mouse_history_entry();
}

void handle_m1_down() {
    if (!handle_window_focus_change()) {
        return;
    }

    gMouseButtonBits |= 1;

    _add_mouse_history_entry();
}

void handle_m1_up() {
    if (!handle_window_focus_change()) {
        return;
    }

    gMouseButtonBits &= 0xfffffffe;

    _add_mouse_history_entry();
}

void handle_m2_down() {
    if (!handle_window_focus_change()) {
        return;
    }

    gMouseButtonBits |= 2;

    _add_mouse_history_entry();
}

void handle_m2_up() {
    if (!handle_window_focus_change()) {
        return;
    }

    gMouseButtonBits &= 0xfffffffd;

    _add_mouse_history_entry();
}

void FUN_004d6680() {
    unsigned int prevButtons;
    
    gPrevScrollWheelDelta = 0;
    if (gScrollWheelDelta != 0) {
        gPrevScrollWheelDelta = gScrollWheelDelta;
    }
    gScrollWheelDelta = 0;

    prevButtons = gSomeMouseButtonBits;
    gSomeMoreMouseButtonBits = prevButtons;
    
    if (gSomeMouseHistoryIdx != gPrevMouseIdx) {
        gCursorX2 = gPrevMouseXs[gSomeMouseHistoryIdx];
        gCursorY2 = gPrevMouseYs[gSomeMouseHistoryIdx];
        gSomeMouseButtonBits = gPrevMouseButtonBits[gSomeMouseHistoryIdx];

        gSomeMouseHistoryIdx += 1;
        if (gSomeMouseHistoryIdx >= 5) {
            gSomeMouseHistoryIdx = 0;
        }
    } else {
        gCursorX2 = gCursorX;
        gCursorY2 = gCursorY;
        gSomeMouseButtonBits = gMouseButtonBits;
    }

    gUnkMouseButtonBits = (gSomeMouseButtonBits ^ prevButtons) & gSomeMouseButtonBits;
}

#pragma ASM_FUNC FUN_004d6740

#pragma ASM_FUNC FUN_004d6790

#pragma ASM_FUNC FUN_004d67e0

#pragma ASM_FUNC FUN_004d6800

#pragma ASM_FUNC FUN_004d6820
