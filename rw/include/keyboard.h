#pragma once

// Array for all virtual key codes where a value of 0 is released and 1 is pressed
extern char gKeysPressed[256];
// Same as [gKeysPressed] but only remains 1 for one tick 
extern char gKeysTapped[256];

extern unsigned int is_key_pressed(int nVirtKey);
extern void update_keys_pressed();
extern int was_key_tapped(int virtKeyCode);
