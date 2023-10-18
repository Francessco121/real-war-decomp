#include <WINDOWS.H>

#define LOCK_FRAMERATE_TO_60 1

void _draw_frame_base();

static DWORD lastTickCount = 0;
const DWORD targetDelta = 16;

void draw_frame_hook() {
    DWORD delta;

    _draw_frame_base();

#if LOCK_FRAMERATE_TO_60
    // Spin-wait to lock the framerate to 60 FPS
    //
    // Letting the game go higher causes the game to run way too fast
    delta = GetTickCount() - lastTickCount;
    while (delta < targetDelta) {
        delta = GetTickCount() - lastTickCount;
    }

    lastTickCount = GetTickCount();
#endif
}
