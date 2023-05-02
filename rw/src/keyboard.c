#include <WINDOWS.H>

#include "keyboard.h"

extern int gWindowFocused;

// Array for all virtual key codes where a value of 0 is released and 1 is pressed
extern char gKeysPressed[256];
// Same as [gKeysPressed] but only remains 1 for one tick 
extern char gKeysTapped[256];

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
