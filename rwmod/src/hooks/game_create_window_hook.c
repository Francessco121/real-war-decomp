#include <WINDOWS.H>

extern int gLaunchWindowed;
extern HWND gWndHandle;
extern int gCursorTextures;
extern int gWindowFocused;

extern LRESULT __stdcall game_wndproc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
extern void FUN_004d8010(int);
extern void load_cursor_textures();

static char gameName[] = "Real War: rwmod";

const int windowedWidth = 808;
const int windowedHeight = 626;

// const int windowedWidth = 1280;
// const int windowedHeight = 960;

int game_create_window_hook(HINSTANCE hInstance, int nCmdShow) {
    WNDCLASSA wndClass;

    wndClass.style = 0;
    wndClass.lpfnWndProc = game_wndproc;
    wndClass.cbClsExtra = 0;
    wndClass.cbWndExtra = 0;
    wndClass.hInstance = hInstance;
    wndClass.hIcon = LoadIconA(NULL, IDI_APPLICATION);
    wndClass.hCursor = LoadCursorA(NULL, IDI_APPLICATION);
    wndClass.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wndClass.lpszMenuName = gameName;
    wndClass.lpszClassName = gameName;
    RegisterClassA(&wndClass);

    if (gLaunchWindowed) {
        gWndHandle = CreateWindowExA(
            0,
            gameName,
            gameName,
            WS_BORDER | WS_SYSMENU | WS_MINIMIZEBOX,
            GetSystemMetrics(SM_CXSCREEN) / 2 + -(windowedWidth / 2),
            GetSystemMetrics(SM_CYSCREEN) / 2 + -(windowedHeight / 2),
            windowedWidth,
            windowedHeight,
            NULL,
            NULL,
            hInstance,
            NULL);

        ShowWindow(gWndHandle, nCmdShow);
        UpdateWindow(gWndHandle);
    } else {
        gWndHandle = CreateWindowExA(
            0,
            gameName,
            gameName,
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
