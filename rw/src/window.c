#include <DDRAW.H>
#include <STDIO.H>
#include <WINDOWS.H>
#include <WINDOWSX.H>

#include "game_dirs.h"
#include "keyboard.h"
#include "mouse.h"
#include "sound.h"
#include "strings.h"
#include "timers.h"
#include "types.h"
#include "undefined.h"
#include "virtual_memory.h"
#include "window.h"
#include "window_graphics.h"

// Not sure why these aren't defined...
#define WM_MOUSEWHEEL 0x20a
#define GET_WHEEL_DELTA_WPARAM(wp) ((int)(short)HIWORD(wp))

#define MAX_CMD_LINE_ARGS 20

HWND gWndHandle;
bool gWindowFocused;
HWND gActiveWindow;
int32 gWindowStatus;

char gCmdLineString[512];
int32 gCmdLineArgCount;
char *gCmdLineToken;
char gCmdLineArgs[MAX_CMD_LINE_ARGS][256];

char gRegValueTemp[256];

int gNCmdShow;
int32 gMemoryInUseBytes;

LRESULT CALLBACK game_wndproc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
bool game_create_window(HINSTANCE hInstance, int nCmdShow);

bool init_systems(HINSTANCE hInstance, int nShowCmd) {
    bool ret;

    ret = FALSE;

    gNCmdShow = nShowCmd;
    gWindowStatus = 0;
    LPCGUID_005a4f84 = &GUID_004ea6c8;

    setup_virtual_memory_buffers();
    init_timers();

    if (game_create_window(hInstance, nShowCmd)) {
        ret = TRUE;

        gMemoryInUseBytes = get_memory_in_use_bytes(str_Start);
        get_memory_in_use_bytes(str_Start);

        pump_messages_and_update_input_state();

        init_sound_system();
        mouse_init();

        gD3DDeviceFound = 0;
        if (gCmdLineArgH != 0) {
            if (FUN_00401100(gWndHandle)) {
                gD3DDeviceFound = 1;
            }
        }
    }

    return ret;
}

bool FUN_004d45b0() {
    return FUN_00401100(gWndHandle);
}

bool game_create_window(HINSTANCE hInstance, int nCmdShow) {
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
        return FALSE;
    }

    SetFocus(gWndHandle);

    FUN_004d8010(1);

    memset(&gCursorTextures, 0, 0x98a0);
    
    load_cursor_textures();

    gWindowFocused = 1;

    return TRUE;
}

LRESULT CALLBACK game_wndproc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
        case WM_CLOSE:
            gWindowStatus = 2;
            return 1;
        case WM_PAINT:
            do_window_paint(hWnd);
            return 0;
        case WM_DESTROY:
            gWindowStatus = 1;
            return 1;
        case WM_NCDESTROY:
            gWindowStatus = 3;
            return 1;
        case WM_KEYUP:
            if (gKeysDown[wParam]) {
                gKeysDown[wParam] = FALSE;
            }
            goto default_;
        case WM_KEYDOWN:
            if (!gKeysDown[wParam]) {
                gKeysDown[wParam] = TRUE;
                gKeyDownHistory[gKeyDownHistoryIdx] = wParam;

                gKeyDownHistoryIdx += 1;
                if (gKeyDownHistoryIdx >= MAX_KEYDOWN_HISTORY) {
                    gKeyDownHistoryIdx = 0;
                }
            }
            goto default_;
        default:
        default_:
            return DefWindowProcA(hWnd, uMsg, wParam, lParam);
        case WM_MOUSEMOVE:
            handle_mouse_move(hWnd, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam), wParam);
            return 0;
        case WM_LBUTTONDOWN:
            handle_m1_down(hWnd, 0, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam), wParam);
            return 0;
        case WM_LBUTTONUP:
            handle_m1_up(hWnd, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam), wParam);
            return 0;
        case WM_RBUTTONDOWN:
            handle_m2_down(hWnd, 0, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam), wParam);
            return 0;
        case WM_RBUTTONUP:
            handle_m2_up(hWnd, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam), wParam);
            return 0;
        case WM_MOUSEWHEEL:
            gCurrentScrollWheelDelta = GET_WHEEL_DELTA_WPARAM(wParam);
            return 1;
    }
}

int APIENTRY WinMain(HINSTANCE hInst, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd) {
    int i;
    uint32 j;
    LPSTR cmdLineStr;
   
    memset(&gKeysTapped, 0, sizeof(gKeysTapped));
    memset(&gKeysPressed, 0, sizeof(gKeysPressed));

    gCmdLineArgN[0] = 0;
    DAT_0051b418 = 0;
    gCmdLineArgM = 0;
    gCmdLineArgT = 0;
    gCmdLineArgC = 1;
    memset(&gCmdLineString, 0, sizeof(gCmdLineString));
    gCmdLineArgL = 0;
    DAT_01b18068 = 0.95f;
    gCmdLineArgE = 0;
    gCmdLineArgB = 1;
    gCmdLineArgS = 0;
    gCmdLineArgP[0] = 0;

    cmdLineStr = GetCommandLineA();
    strcpy(gCmdLineString, cmdLineStr);

    for (i = 0; gCmdLineString[i] != 0; i++) {
        if (gCmdLineString[i] == '#') {
            gCmdLineString[i] = ' ';
        } else if (gCmdLineString[i] == '-' && gCmdLineString[i + 1] == 'P') {
            gCmdLineString[i - 1] = ' ';
        } else if (gCmdLineString[i] == '"') {
            gCmdLineString[i] = ' ';
        } else if (gCmdLineString[i] == ' ' && gCmdLineString[i + 1] != '-' && gCmdLineString[i + 1] != '/') {
            gCmdLineString[i] = '+';
        }
    }

    strtok(gCmdLineString, str_space_tab);
    for (gCmdLineArgCount = 1; gCmdLineArgCount < MAX_CMD_LINE_ARGS; gCmdLineArgCount++) {
        gCmdLineToken = strtok(NULL, str_space_tab);
        if (gCmdLineToken == NULL) {
            break;
        }

        strcpy(gCmdLineArgs[gCmdLineArgCount], gCmdLineToken);
    }

    for (i = 1; i < gCmdLineArgCount; i++) {
        if (gCmdLineArgs[i][0] != '-') {
            continue;
        }

        if (gCmdLineArgs[i][1] == 'M') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgM);
        } else if (gCmdLineArgs[i][1] == 'C') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgC);
        } else if (gCmdLineArgs[i][1] == 'L') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgL);
        } else if (gCmdLineArgs[i][1] == 'T') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgT);
        } else if (gCmdLineArgs[i][1] == 'F') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgF);
        } else if (gCmdLineArgs[i][1] == 'L') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgL);
        } else if (gCmdLineArgs[i][1] == 'G') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gLaunchWindowed);
        } else if (gCmdLineArgs[i][1] == 'E') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgE);
        } else if (gCmdLineArgs[i][1] == 'H') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgH);
        } else if (gCmdLineArgs[i][1] == 'B') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgB);
        } else if (gCmdLineArgs[i][1] == 'N') {
            sscanf(&gCmdLineArgs[i][2], str_pct_s, &gCmdLineArgN);
            j = 0;
            while ((gCmdLineArgN[j] >= '0' && gCmdLineArgN[j] <= '9') || gCmdLineArgN[j] == '.') {
                j += 1;
            }
            gCmdLineArgN[j] = '\0';
        } else if (gCmdLineArgs[i][1] == 'P') {
            sscanf(&gCmdLineArgs[i][2], str_pct_s, &gCmdLineArgP);
            for (j = 0; j < strlen(gCmdLineArgP); j++) {
                if (gCmdLineArgP[j] == '+') {
                    gCmdLineArgP[j] = ' ';
                }
            }
        } else if (gCmdLineArgs[i][1] == 'S') {
            sscanf(&gCmdLineArgs[i][2], str_pct_d, &gCmdLineArgS);
            gCmdLineArgS += 1;
            DAT_0051b418 = ((gCmdLineArgS - 1) == 0) - 2;
        } else if (gCmdLineArgs[i][1] == 'R') {
            set_game_registry_value(str_dirtree_3, &gCmdLineArgs[i][2]);
            sprintf(gRegValueTemp, str_pct_s_data_slash, &gCmdLineArgs[i][2]);
            set_game_registry_value(str_datatree_2, gRegValueTemp);
            sprintf(gRegValueTemp, str_pct_s_vids_slash, &gCmdLineArgs[i][2]);
            set_game_registry_value(str_vidtree_2, gRegValueTemp);
        }
    }

    if (!init_systems(hInst, nShowCmd)) {
        return 0;
    }

    load_game_dirs_from_registry();
    ShowCursor(FALSE);
    cd_check();

    game_main();
    game_exit();
}

void display_messagebox_and_exit(const char *message) {
    display_messagebox(message);
    game_exit();
}

void game_exit() {
    MSG msg;

    while (get_key_state(VK_F4) & 0x8000) {
        while (PeekMessageA(&msg, NULL, 0, 0, PM_NOREMOVE)) {
            GetMessageA(&msg, NULL, 0, 0);
            TranslateMessage(&msg);
            DispatchMessageA(&msg);
        }
    }

    FUN_004a5c30();
    FUN_0047a020();
    FUN_004c8ab0();
    deinit_sound_system();
    FUN_00401b40();

    gDontReleaseDirectDraw = 0;
    free_graphics_stuff();

    _fcloseall();
    free_all_virtual_memory_buffers();

    exit(1);
}

void display_messagebox(const char *format, ...) {
    char buffer[300];
    va_list args;

    va_start(args, format);
    vsprintf(buffer, format, args);
    va_end(args);

    if (gDDFrontBuffer != NULL) {
        IDirectDraw4_FlipToGDISurface(gDirectDraw4);
    }

    MessageBoxA(gWndHandle, buffer, str_Message_dotdotdot, MB_OK);
}

bool display_yesno_messagebox(const char *message) {
    if (gDDFrontBuffer != NULL) {
        IDirectDraw4_FlipToGDISurface(gDirectDraw4);
    }

    return MessageBoxA(gWndHandle, message, str_Message_dotdotdot, MB_YESNO | MB_DEFBUTTON2) == IDYES;
}

int32 get_next_buffered_key() {
    int32 bufferedKey; 

    if (gKeyDownBufferIdx == gKeyDownHistoryIdx) {
        return 0;
    }

    bufferedKey = gKeyDownHistory[gKeyDownBufferIdx];
    gKeyDownHistory[gKeyDownBufferIdx] = 0;

    gKeyDownBufferIdx += 1;
    if (gKeyDownBufferIdx >= MAX_KEYDOWN_HISTORY) {
        gKeyDownBufferIdx = 0;
    }

    return bufferedKey;
}

void reset_keydown_buffer() {
    gKeyDownBufferIdx = gKeyDownHistoryIdx;
}

void pump_messages_and_update_input_state() {
    MSG msg;

    while (PeekMessageA(&msg, NULL, 0, 0, PM_NOREMOVE)) {
        GetMessageA(&msg, NULL, 0, 0);
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }

    update_mouse_state();

    if (handle_window_focus_change()) {
        set_cursor_pos(gCursorUnbufferedX, gCursorUnbufferedY);
    }

    update_keys_pressed();

    if (gWindowStatus != 0) {
        game_exit();
    }
}

void pump_messages() {
    MSG msg;

    while (PeekMessageA(&msg, NULL, 0, 0, PM_NOREMOVE)) {
        GetMessageA(&msg, NULL, 0, 0);
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }

    if (handle_window_focus_change()) {
        set_cursor_pos(gCursorUnbufferedX, gCursorUnbufferedY);
    }

    if (gWindowStatus != 0) {
        game_exit();
    }
}

#ifdef NON_MATCHING
bool handle_window_focus_change() {
    HWND focus;

    gActiveWindow = GetActiveWindow();
    focus = GetFocus();

    if (focus != gWndHandle || gActiveWindow == NULL || gActiveWindow != gWndHandle) {
        if (!gWindowFocused && !gBitmapCreated && gDirectDraw4 != NULL) {
            IDirectDraw4_FlipToGDISurface(gDirectDraw4);
        }

        gWindowFocused = FALSE;
        return FALSE;
    } else {
        if (!gWindowFocused) {
            if (gBitmapCreated) {
                do_window_paint(NULL);
            } else {
                if (gDDFrontBuffer != NULL) {
                    IDirectDrawSurface4_Restore(gDDFrontBuffer);
                }
                if (gDDBackBuffer != NULL) {
                    IDirectDrawSurface4_Restore(gDDBackBuffer);
                }
            }
        }

        gWindowFocused = TRUE;
        return TRUE;
    }
}
#else
#pragma ASM_FUNC handle_window_focus_change hasret
#endif
