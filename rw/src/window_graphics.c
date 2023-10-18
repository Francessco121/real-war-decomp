#include <DDRAW.H>
#include <STDIO.H>
#include <WINDOWS.H>

#include "types.h"
#include "strings.h"
#include "timers.h"
#include "undefined.h"
#include "virtual_memory.h"
#include "window.h"
#include "window_graphics.h"

// .data

BITMAPINFO *gBitmapInfo; // = &BITMAPINFO_0051b898

// .bss

int32 DAT_0051b978;

uint16 g16BitColorPallete[65536];

int32 DAT_005a4f80;

int32 DAT_0051b960;
int32 DAT_0051b964;
int32 DAT_0051b968;

IDirectDraw *gDirectDraw;

bool gCoInitialized;

int32 gDisplayBPP;
int32 gPrimarySurfaceBufferByteSize;
int32 gDisplayWidth;
int32 gDisplayHeight;

bool gBitmapCreated;

uint16 *gInMemoryGraphicsSurface;
uint16 *gBitmapData;
HBITMAP gBitmap;

int32 gBlitsPerMs;
int32 gBlitsPerS;

// .text

void create_some_bitmap();
void determine_backbuffer_pixel_format();
void draw_timers();

const char *get_last_graphics_error_reason() {
    return gTempString2;
}

bool set_cursor_pos(int32 x, int32 y) {
    if (gBitmapCreated) {
        return FALSE;
    }

    return SetCursorPos(x, y);
}

bool some_graphics_init(int32 width, int32 height, int32 bpp) {
    free_graphics_stuff();

    if (!gCoInitialized) {
        gCoInitialized = TRUE;
        CoInitialize(NULL);
    }

    gDisplayBPP = bpp;
    gDisplayWidth = width;
    gDisplayHeight = height;
    gPrimarySurfaceBufferByteSize = (bpp >> 3) * width * height;

    create_some_bitmap();

    gBitmapCreated = TRUE;
    gInMemoryGraphicsSurface = gBitmapData;

    return TRUE;
}

void do_window_paint(HWND hWnd) {
    HBITMAP hBitmap;
    PAINTSTRUCT paint;
    HDC hdcDest;
    HDC hdcSrc;
    BITMAP bitmap;
    HGDIOBJ prevObj;
    
    if (!gBitmapCreated) {
        BeginPaint(hWnd, &paint);
        EndPaint(hWnd, &paint);
        return;
    }

    hBitmap = gBitmap;
    
    if (hWnd != NULL) {
        hdcDest = BeginPaint(hWnd, &paint);
    } else {
        hdcDest = GetDC(gWndHandle);
    }

    hdcSrc = CreateCompatibleDC(hdcDest);
    GetObjectA(hBitmap, sizeof(BITMAP), &bitmap);
    prevObj = SelectObject(hdcSrc, hBitmap);

    if (hWnd == NULL) {
        BitBlt(
            /*hdc*/ hdcDest,
            /*x*/ 400 - gDisplayWidth / 2,
            /*y*/ 300 - gDisplayHeight / 2,
            /*cx*/ bitmap.bmWidth,
            /*cy*/ bitmap.bmHeight,
            /*hdcSrc*/ hdcSrc,
            /*x1*/ 0,
            /*y1*/ 0,
            /*rop*/ SRCCOPY
        );
    }

    SelectObject(hdcSrc, prevObj);
    DeleteDC(hdcSrc);

    if (hWnd != NULL) {
        EndPaint(hWnd, &paint);
    } else {
        ReleaseDC(NULL, hdcDest);
    }
}

void delete_bitmap() {
    DeleteObject(gBitmap);
    gBitmapCreated = FALSE;
}

void create_some_bitmap() {
    RGBQUAD *bmiColors;
    HDC hdc;
    uint32 width;
    uint32 height;

    bmiColors = gBitmapInfo->bmiColors;

    hdc = GetDC(NULL);

    width = ((gDisplayWidth * 2) + 3) & ~3;
    height = gDisplayHeight;

    gBitmapInfo->bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    gBitmapInfo->bmiHeader.biWidth = gDisplayWidth;
    gBitmapInfo->bmiHeader.biHeight = -gDisplayHeight;
    gBitmapInfo->bmiHeader.biPlanes = 1;
    gBitmapInfo->bmiHeader.biBitCount = 16;
    gBitmapInfo->bmiHeader.biCompression = BI_BITFIELDS;
    gBitmapInfo->bmiHeader.biSizeImage = width * height;
    gBitmapInfo->bmiHeader.biXPelsPerMeter = 0;
    gBitmapInfo->bmiHeader.biYPelsPerMeter = 0;
    gBitmapInfo->bmiHeader.biClrUsed = 0;
    gBitmapInfo->bmiHeader.biClrImportant = 0;

    *((uint32*)(&bmiColors[0])) = 0x7c00;
    *((uint32*)(&bmiColors[1])) = 0x03e0;
    *((uint32*)(&bmiColors[2])) = 0x001f;

    gBitmap = CreateDIBSection(hdc, gBitmapInfo, DIB_RGB_COLORS, &gBitmapData, NULL, 0);

    memset(gBitmapData, 0, gBitmapInfo->bmiHeader.biSizeImage);

    ReleaseDC(NULL, hdc);
}

bool init_directx(int32 displayWidth, int32 displayHeight, int32 displayBpp) {
    HRESULT hresult;
    int32 prevVirtualMemoryBufferNumber;
    DDSURFACEDESC2 surfaceDesc;
    DDSCAPS backbufferCaps;
    int32 surfaceByteSize;
    int32 i;

    prevVirtualMemoryBufferNumber = gVirtualMemoryBufferNumber;
    gVirtualMemoryBufferNumber = 0;

    DAT_0051b8e0 = 0;

    if (gDisplayWidth != displayWidth || 
        gDisplayHeight != displayHeight || 
        gDisplayBPP != displayBpp ||
        DAT_0051b978 != 0
    ) {
        gDontReleaseDirectDraw = TRUE;

        free_all_cursor_textures();

        if (gD3DDeviceFound) {
            FUN_00406e60();
        }

        free_graphics_stuff();

        gDontReleaseDirectDraw = FALSE;

        if (!gCoInitialized) {
            gCoInitialized = TRUE;
            CoInitialize(NULL);
        }

        gDisplayBPP = displayBpp;
        gDisplayWidth = displayWidth;
        gDisplayHeight = displayHeight;
        surfaceByteSize = (displayBpp >> 3) * displayWidth * displayHeight;
        gPrimarySurfaceBufferByteSize = surfaceByteSize;

        if (gDirectDraw4 == NULL) {
            hresult = DirectDrawCreate(NULL, &gDirectDraw, NULL);
            if (hresult != DD_OK) {
                sprintf(gTempString2, str_Failed_on_D_Draw_Create_Primary);
                return FALSE;
            }

            hresult = IDirectDraw_QueryInterface(gDirectDraw, &IID_IDirectDraw4, &gDirectDraw4);
            if (hresult != S_OK) {
                sprintf(gTempString2, str_Failed_On_D_Draw_Create_Query);
                return FALSE;
            }

            hresult = IDirectDraw4_SetCooperativeLevel(gDirectDraw4, gWndHandle, 
                DDSCL_FULLSCREEN | DDSCL_ALLOWREBOOT | DDSCL_EXCLUSIVE | DDSCL_ALLOWMODEX);
            if (hresult != DD_OK) {
                sprintf(gTempString2, str_Failed_Set_Coop);
                return FALSE;
            }
        }

        get_available_vid_memory();
        if (gD3DDeviceFound && !gDontInitD3D) {
            if (!init_d3d(gWndHandle)) {
                sprintf(gTempString2, str_Failed_Create_D3D_render);
                return FALSE;
            }
        }

        hresult = IDirectDraw4_SetDisplayMode(gDirectDraw4, gDisplayWidth, gDisplayHeight, gDisplayBPP, 0, 0);
        if (hresult != DD_OK) {
            sprintf(gTempString2, str_Failed_Set_Display);
            return FALSE;
        }

        memset(&surfaceDesc, 0, sizeof(surfaceDesc));
        surfaceDesc.dwSize = sizeof(DDSURFACEDESC2);
        surfaceDesc.dwFlags = DDSD_CAPS | DDSD_BACKBUFFERCOUNT;
        surfaceDesc.ddsCaps.dwCaps = 
            ((gD3DDeviceFound != 0) ? DDSCAPS_3DDEVICE : 0) +
            (DDSCAPS_COMPLEX |
            DDSCAPS_FLIP |
            DDSCAPS_PRIMARYSURFACE);
        surfaceDesc.dwBackBufferCount = 1;

        hresult = IDirectDraw4_CreateSurface(gDirectDraw4, &surfaceDesc, &gDDFrontBuffer, NULL);
        if (hresult != DD_OK) {
            sprintf(gTempString2, str_Failed_on_Front_Buffer);
            return FALSE;
        }

        if (gD3DDeviceFound) {
            backbufferCaps.dwCaps = DDSCAPS_BACKBUFFER;

            // BUG: This function is given a DDSCAPS struct (not DDSCAPS2) which has less fields than the function expects
            hresult = IDirectDrawSurface4_GetAttachedSurface(gDDFrontBuffer, (DDSCAPS2*)&backbufferCaps, &gDDBackBuffer);
            if (hresult != DD_OK) {
                sprintf(gTempString2, str_Failed_on_Back_Buffer);
                return FALSE;
            }

            if (gD3DDeviceFound) {
                if (FUN_004013f0(gWndHandle) == 0) {
                    sprintf(gTempString2, str_Failed_Creating_D3D_Devices);
                    return FALSE;
                }
            }
        }

        gInMemoryGraphicsSurface = custom_alloc(surfaceByteSize);

        if (gDisplayBPP == 16) {
            for (i = 0; i < 65536; i++) {
                g16BitColorPallete[i] = 
                    (uint16)((((uint8)(i >> 10) & 0x1f) << 11) 
                    | (((uint8)(i >> 5) & 0x1f) << 6) 
                    | (uint8)(i & 0x1f));
            }
        }

        determine_backbuffer_pixel_format();
        clear_in_memory_graphics_surface();

        if (gDDBackBuffer != NULL) {
            clear_surface(gDDBackBuffer, 0);
            IDirectDrawSurface4_Flip(gDDFrontBuffer, NULL, DDFLIP_DONOTWAIT);
        } else {
            clear_surface(gDDFrontBuffer, 0);
        }

        if (gD3DDeviceFound) {
            FUN_00406ed0();
        }

        load_cursor_textures();

        if (gDisplayWidth == displayWidth && gDisplayHeight == displayHeight && gDisplayBPP == displayBpp) {
            DAT_0051b978 -= 1;
        } else {
            DAT_0051b978 += 1;
        }

        DAT_01b18068 = 0.95f;
        DAT_005a4f80 = 0;
        DAT_0051add4 = 0;
    }

    gVirtualMemoryBufferNumber = prevVirtualMemoryBufferNumber;
    return TRUE;
}

void determine_backbuffer_pixel_format() {
    LPDIRECTDRAWSURFACE4 surface;
    DDPIXELFORMAT format;

    memset(&format, 0, sizeof(format));
    format.dwSize = sizeof(DDPIXELFORMAT);

    surface = gDDBackBuffer;
    if (gDDBackBuffer == NULL) {
        surface = gDDFrontBuffer;
    }

    IDirectDrawSurface4_GetPixelFormat(surface, &format);
 
    if (format.dwFourCC != 0) {
        DAT_0051b960 = 0;

        if (format.dwFourCC & 32) {
            DAT_0051b968 = 0;
            DAT_0051b964 = 1;
        } else if (format.dwFourCC & 8) {
            DAT_0051b968 = 1;
            DAT_0051b964 = 0;
        }
    } else {
        if (format.dwRGBBitCount == 16 &&
            (format.dwRBitMask != 0xf800 || format.dwGBitMask != 0x7e0 || format.dwBBitMask != 0x1f)
        ) {
            // 16-bit, NOT A1R5G5B5
            DAT_0051b968 = 0;
            DAT_0051b964 = 0;
            DAT_0051b960 = 1;
        } else {
            // 16-bit, A1R5G5B5
            // Note: This seems to be the path modern computers go down
            DAT_0051b968 = 0;
            DAT_0051b964 = 0;
            DAT_0051b960 = 0;
        }
    }
}

void free_graphics_stuff() {
    if (gBitmapCreated) {
        delete_bitmap();
    }

    gDisplayWidth = 0;
    gDisplayHeight = 0;
    gDisplayBPP = 0;

    FUN_0041a8e0();

    if (gDDBackBuffer != NULL) {
        IDirectDrawSurface4_Restore(gDDBackBuffer);
    }
    if (gDDFrontBuffer != NULL) {
        IDirectDrawSurface4_Restore(gDDFrontBuffer);
    }

    if (gInMemoryGraphicsSurface != NULL) {
        custom_free(&gInMemoryGraphicsSurface);
    }
    gInMemoryGraphicsSurface = NULL;

    FUN_00401870(gWndHandle);

    if (gDDBackBuffer != NULL) {
        IDirectDrawSurface4_Release(gDDBackBuffer);
    }
    gDDBackBuffer = NULL;
    if (gDDFrontBuffer != NULL) {
        IDirectDrawSurface4_Release(gDDFrontBuffer);
    }
    gDDFrontBuffer = NULL;

    if (!gDontReleaseDirectDraw) {
        if (gDirectDraw4 != NULL) {
            IDirectDraw4_Release(gDirectDraw4);
        }
        gDirectDraw4 = NULL;

        if (gDirectDraw != NULL) {
            IDirectDraw_Release(gDirectDraw);
        }
        gDirectDraw = NULL;

        if (gCoInitialized) {
            CoUninitialize();
        }
        gCoInitialized = FALSE;
    }
}

void clear_surface(LPDIRECTDRAWSURFACE4 surface, uint32 color) {
    DDBLTFX fx;
    fx.dwSize = sizeof(DDBLTFX);
    fx.dwFillColor = color;

    IDirectDrawSurface4_Blt(surface, NULL, NULL, NULL, DDBLT_COLORFILL | DDBLT_WAIT, &fx);
}

void clear_in_memory_graphics_surface() {
    memset_dword((uint32*)gInMemoryGraphicsSurface, 0, gPrimarySurfaceBufferByteSize >> 2);
}

void *get_in_memory_graphics_surface(int32 *width, int32 *height) {
    if (width != NULL) {
        *width = gDisplayWidth;
    }

    if (height != NULL) {
        *height = gDisplayHeight;
    }

    return gInMemoryGraphicsSurface;
}

#ifdef NON_MATCHING
void draw_frame() {
    DDSURFACEDESC2 surfaceDesc;
    int32 widthBytes;
    int32 x, y;
    uint16 *src;
    uint16 *dst;
    int32 widthDiff;

    DAT_01b18068 = 1e-05f;
    FUN_004d7bc0();
    DAT_005a4f80 = DAT_0051add4;
    DAT_0051add4 = 0;

    if (!handle_window_focus_change() && !gBitmapCreated) {
        return;
    }

    FUN_0041a830();
    DAT_01b18068 = 0.95f;

    if (gCmdLineArgT) {
        draw_timers();
    }

    set_timer_label_and_update_cycle_counter(TIMER_WINDOWS_BLIT, str_Windows_Blit);

    if (gBitmapCreated) {
        // Runs in windowed mode
        gBlitsPerMs = GetTickCount();
        do_window_paint(NULL);
    } else {
        // Runs in fullscreen mode
        surfaceDesc.dwSize = sizeof(DDSURFACEDESC2);
        DAT_00567aa0 = 0xffffffff;

        if (gDDBackBuffer != NULL) {
            DAT_00567aa0 = IDirectDrawSurface4_Lock(gDDBackBuffer, NULL, &surfaceDesc, 0, NULL);
            if (DAT_00567aa0 != DD_OK) {
                update_timer_cycle_delta(TIMER_WINDOWS_BLIT);
                return;
            }
        } else {
            DAT_00567aa0 = IDirectDrawSurface4_Lock(gDDFrontBuffer, NULL, &surfaceDesc, 0, NULL);
            if (DAT_00567aa0 != DD_OK) {
                update_timer_cycle_delta(TIMER_WINDOWS_BLIT);
                return;
            }
        }

        gBlitsPerMs = GetTickCount();

        dst = (uint16*)surfaceDesc.lpSurface;
        src = (uint16*)gInMemoryGraphicsSurface;

        if (gDisplayBPP != 16 || DAT_0051b960 != 0) {
            widthBytes = (gDisplayBPP >> 3) * gDisplayWidth;

            for (y = 0; y < gDisplayHeight; y++) {
                memcpy_dword((uint32*)dst, (uint32*)src, widthBytes >> 2);
                dst += surfaceDesc.lPitch;
                src += widthBytes;
            }
        } else if (gDisplayBPP == 16 && DAT_0051b960 == 0) {
            widthDiff = (surfaceDesc.lPitch >> 1) - gDisplayWidth;

            if (widthDiff == 0) {
                for (y = 0; y < gDisplayHeight; y++) {
                    for (x = 0; x < gDisplayWidth; x++) {
                        *dst = g16BitColorPallete[*src];
                        dst += 1;
                        src += 1;
                    }
                }
            } else {
                for (y = 0; y < gDisplayHeight; y++) {
                    for (x = 0; x < gDisplayWidth; x++) {
                        *dst = g16BitColorPallete[*src];
                        dst += 1;
                        src += 1;
                    }

                    dst += widthDiff;
                }
            }
        }

        if (gDDBackBuffer != NULL) {
            IDirectDrawSurface4_Unlock(gDDBackBuffer, NULL);
        } else {
            IDirectDrawSurface4_Unlock(gDDFrontBuffer, NULL);
        }

        if (gD3DDeviceFound && DAT_005a4f80 > 0) {
            FUN_00406fc0();
            FUN_00401b90(DAT_005a4f80);
            FUN_00406f30();

            // BUG: wtf??? why does this use the backbuffer vtable but pass frontbuffer as this?
            while ((gDDBackBuffer)->lpVtbl->GetBltStatus(gDDFrontBuffer, DDGBS_ISBLTDONE) != DD_OK) { }
        } else {
            DAT_005a4f80 = 0;
        }

        if (gDDBackBuffer != NULL) {
            // BUG: This is passing  DX7 flag to a DX4-6 interface (it does work tho)
            IDirectDrawSurface4_Flip(gDDFrontBuffer, NULL, DDFLIP_DONOTWAIT);
        }
    }

    FUN_004d7d60();
    gBlitsPerMs = GetTickCount() - gBlitsPerMs;

    update_timer_cycle_delta(TIMER_WINDOWS_BLIT);
}
#else
#pragma ASM_FUNC draw_frame
#endif

void draw_timers() {
    int32 local1;
    int32 local2;
    int32 local3;
    int32 local4;
    int32 local5;
    int32 lines;
    int32 i;
    int32 prevValue1;
    int32 prevValue2;

    FUN_004c3b60(&local1, &local2, &local3, &local4, &local5);

    prevValue1 = DAT_00fe04d0;
    prevValue2 = DAT_0051b7f4;

    FUN_004c3ac0(0, 0xff, 0xff, 0xff);

    lines = 1;

    if (get_timer_cycle_delta(TIMER_CLOCKERS) != 0) {
        FUN_004c39f0(timer_tostring(TIMER_CLOCKERS), 0, lines * 8);
        lines += 1;
    }

    if (get_timer_cycle_delta(TIMER_RESOLUTION_PER_FRAME) != 0) {
        FUN_004c39f0(timer_tostring(TIMER_RESOLUTION_PER_FRAME), 0, lines * 8);
        lines += 1;
    }

    for (i = 0; i < (NUM_TIMERS - 2); i++) {
        if (increment_timer_total_for_avg(i) != 0) {
            FUN_004c39f0(timer_tostring(i), 0, lines * 8);
            lines += 1;
        }

        reset_timer_cycle_counter(i);
    }

    if (gBlitsPerS != 0 && gBlitsPerMs != 0) {
        gBlitsPerS = ((1000 / gBlitsPerMs) + gBlitsPerS) / 2;
    } else if (gBlitsPerS == 0 && gBlitsPerMs != 0) {
        gBlitsPerS = 1000 / gBlitsPerMs;
    } else {
        gBlitsPerS = 1000;
    }

    sprintf(gTempString2, str_Blit_Tick_Counts_eq_Blits_Per_S, gBlitsPerS);
    FUN_004c39f0(gTempString2, 0, lines * 8);
    FUN_004c3ac0(local1, local2, local3, local4);

    DAT_00fe04d0 = prevValue1;
    DAT_0051b7f4 = prevValue2;
}
