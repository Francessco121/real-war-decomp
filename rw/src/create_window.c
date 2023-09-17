#include <WINDOWS.H>

#include "create_window.h"
#include "strings.h"
#include "undefined.h"

extern LRESULT __stdcall game_wndproc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

int game_create_window(HINSTANCE hInstance, int nCmdShow) {
    WNDCLASSA wndClass;

    wndClass.style = 0;
    wndClass.lpfnWndProc = game_wndproc;
    wndClass.cbClsExtra = 0;
    wndClass.cbWndExtra = 0;
    wndClass.hInstance = hInstance;
    wndClass.hIcon = LoadIconA(NULL, IDI_APPLICATION);
    wndClass.hCursor = LoadCursorA(NULL, IDI_APPLICATION);
    wndClass.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wndClass.lpszMenuName = str_real_war_v9_dot_25;
    wndClass.lpszClassName = str_real_war_v9_dot_25;
    RegisterClassA(&wndClass);

    if (gLaunchWindowed) {
        gWndHandle = CreateWindowExA(
            0,
            str_real_war_v9_dot_25,
            str_real_war_v9_dot_25,
            WS_BORDER | WS_SYSMENU | WS_MINIMIZEBOX,
            GetSystemMetrics(SM_CXSCREEN) / 2 + -400,
            GetSystemMetrics(SM_CYSCREEN) / 2 + -300,
            808,
            626,
            NULL,
            NULL,
            hInstance,
            NULL);

        ShowWindow(gWndHandle, nCmdShow);
        UpdateWindow(gWndHandle);
    } else {
        gWndHandle = CreateWindowExA(
            0,
            str_real_war_v9_dot_25,
            str_real_war_v9_dot_25,
            WS_POPUP,
            GetSystemMetrics(SM_CXSCREEN) / 2 + -400,
            GetSystemMetrics(SM_CYSCREEN) / 2 + -300,
            800,
            600,
            NULL,
            NULL,
            hInstance,
            NULL);
    }

    if (gWndHandle == NULL) {
        return 0;
    }

    SetFocus(gWndHandle);

    FUN_004d8010(1);

    memset(&gCursorTextures, 0, 0x98a0);
    
    load_cursor_textures();

    gWindowFocused = 1;

    return 1;
}
