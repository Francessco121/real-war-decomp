#include <WINDOWS.H>

#include "keyboard.h"
#include "types.h"
#include "undefined.h"

bool8 gKeysPressed[256];
bool8 gKeysTapped[256];

uint32 get_key_state(int nVirtKey) {
    if (gWindowFocused) {
        return GetKeyState(nVirtKey) & 0x8000;
    }

    return FALSE;
}

void update_keys_pressed() {
    int i;
    int32 lastTick;

    for (i = 1; i < 256; i++) {
        lastTick = gKeysPressed[i];
        gKeysPressed[i] = (bool8)((get_key_state(i) >> 15) & 1);
        gKeysTapped[i] = (bool8)((gKeysPressed[i] ^ lastTick) & gKeysPressed[i]);
    }
}

bool was_key_tapped(int virtKeyCode) {
    return gKeysTapped[virtKeyCode];
}
