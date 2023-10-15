#include <STDIO.H>
#include <WINDOWS.H>
#include <WINDOWSX.H>

#include "create_window.h"
#include "game_dirs.h"
#include "keyboard.h"
#include "mouse.h"
#include "strings.h"
#include "types.h"
#include "undefined.h"

// Not sure why these aren't defined...
#define WM_MOUSEWHEEL 0x20a
#define GET_WHEEL_DELTA_WPARAM(wp) ((int)(short)HIWORD(wp))

extern int32 gKeyDownHistoryIdx;
extern int32 gKeyDownHistory[32];
extern bool8 gKeysDown[256];

extern int32 DAT_0051b418;
extern float32 DAT_01b18068;

extern char gCmdLineArgN[];
extern int32 gCmdLineArgM;
extern int32 gCmdLineArgT;
extern int32 gCmdLineArgC;
extern int32 gCmdLineArgL;
extern int32 gCmdLineArgE;
extern int32 gCmdLineArgB;
extern int32 gCmdLineArgS;
extern char gCmdLineArgP[];
extern int32 gCmdLineArgF;
extern int32 gCmdLineArgH;

char gCmdLineString[512];
int32 gCmdLineArgCount;
char *gCmdLineToken;
char gCmdLineArgs[20][256];

char gRegValueTemp[256];

int32 gWindowStatus;

extern int init_systems(HINSTANCE hInstance, int nShowCmd);
extern void do_window_paint(HWND hWnd);

extern LRESULT CALLBACK game_wndproc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

#pragma ASM_FUNC init_systems hasret

#pragma ASM_FUNC FUN_004d45b0

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
                if (gKeyDownHistoryIdx >= 32) {
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
    for (gCmdLineArgCount = 1; gCmdLineArgCount < 20; gCmdLineArgCount++) {
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
    return game_exit();
}

#pragma ASM_FUNC display_message_and_exit

#pragma ASM_FUNC game_exit hasret

#pragma ASM_FUNC display_message

#pragma ASM_FUNC FUN_004d4e70

#pragma ASM_FUNC FUN_004d4eb0

#pragma ASM_FUNC FUN_004d4ef0

#pragma ASM_FUNC FUN_004d4f00

#pragma ASM_FUNC FUN_004d4fa0

#pragma ASM_FUNC handle_window_focus_change hasret
