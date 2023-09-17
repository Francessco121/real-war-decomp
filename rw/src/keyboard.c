#include <WINDOWS.H>

#include "keyboard.h"
#include "undefined.h"

unsigned int is_key_pressed(int nVirtKey) {
    if (gWindowFocused) {
        return GetKeyState(nVirtKey) & 0x8000;
    }

    return FALSE;
}

void update_keys_pressed() {
    int i;
    int lastTick;

    for (i = 1; i < 256; i++) {
        lastTick = gKeysPressed[i];
        gKeysPressed[i] = (is_key_pressed(i) >> 15) & 1;
        gKeysTapped[i] = (gKeysPressed[i] ^ lastTick) & gKeysPressed[i];
    }
}

int was_key_tapped(int virtKeyCode) {
    return gKeysTapped[virtKeyCode];
}
