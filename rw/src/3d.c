#include <DDRAW.h>
#include <D3D.h>
#include <UNKNWN.H>

#include "types.h"
#include "undefined.h"
#include "virtual_memory.h"
#include "window.h"
#include "window_graphics.h"

#define MAX_ENUM_DEVICES 10

typedef struct UnkD3dStruct1 {
    DWORD dwSize;
    float32 unk0x4;
    float32 unk0x8;
    float32 unk0xc;
    int32 unk0x10;
    float32 unk0x14;
    float32 unk0x18;
    float32 unk0x1c;
    int32 unk0x20[11];
    int32 unk0x4c;
} UnkD3dStruct1;

typedef struct UnkTexStruct1 {
    /*0x0*/ uint16 *texBytes;
    /*0x4*/ int32 width;
    /*0x8*/ int32 height;
    /*0xc*/ int32 widthMultipleOfMin;
    /*0x10*/ int32 heightMultipleOfMin;
    /*0x14*/ char unk0x0_pad[16];
    /*0x24*/ int32 unk0x24;
    /*0x28*/ int32 unk0x28;
    /*0x2c*/ int32 unk0x2c;
    /*0x30*/ int32 unk0x30;
    /*0x34*/ int32 unk0x34[32]; // unsure of length
    /*0xb4*/ LPDIRECTDRAWSURFACE4 surface;
    /*0xb8*/ LPDIRECT3DTEXTURE2 texture;
    /*0xbc*/ char *unk0xbc;
    /*0xc0*/ void *unk0xc0;
} UnkTexStruct1;

typedef struct UnkGraphicsStruct4 {
    DWORD left;
    DWORD top;
    DWORD right;
    DWORD bottom;
} UnkGraphicsStruct4;

typedef struct UnkModelStruct {
    /*0x0*/ char unk0x0;
    /*0x1*/ char unk0x1;
    /*0x2*/ int16 unk0x2;
    /*0x4*/ char unk0x4_pad[48];
    /*0x34*/ float32 x1;
    /*0x38*/ float32 x2;
    /*0x3c*/ float32 x3;
    /*0x40*/ int32 unk0x40_pad;
    /*0x44*/ float32 y1;
    /*0x48*/ float32 y2;
    /*0x4c*/ float32 y3;
    /*0x50*/ int32 unk0x50_pad;
    /*0x54*/ float32 z1;
    /*0x58*/ float32 z2;
    /*0x5c*/ float32 z3;
    /*0x60*/ char unk0x60_pad[100];
    /*0xc4*/ short unk0xc4; // r
    /*0xc6*/ short unk0xc6; // r
    /*0xc8*/ short unk0xc8; // r
    /*0xca*/ short unk0xca;
    /*0xcc*/ short unk0xcc; // g
    /*0xce*/ short unk0xce; // g
    /*0xd0*/ short unk0xd0; // g
    /*0xd2*/ short unk0xd2;
    /*0xd4*/ short unk0xd4; // b
    /*0xd6*/ short unk0xd6; // b
    /*0xd8*/ short unk0xd8; // b
    /*0xda*/ short unk0xda;
    /*0xdc*/ int32 tu1;
    /*0xe0*/ int32 tu2;
    /*0xe4*/ int32 tu3;
    /*0xe8*/ int32 unk0xe8_pad;
    /*0xec*/ int32 tv1;
    /*0xf0*/ int32 tv2;
    /*0xf4*/ int32 tv3;
    /*0xf8*/ char unk0xf8_pad[8];
    /*0x100*/ short unk0x100;
    /*0x102*/ short unk0x102;
    /*0x104*/ int32 unk0x104_pad;
    /*0x108*/ int32 unk0x108;
} UnkModelStruct;

typedef struct UnkModelStruct2 {
    /*0x0*/ int32 unk0x0;
    /*0x4*/ int32 unk0x4;
    /*0x8*/ int32 unk0x8;
    /*0xc*/ char unk0xc_pad[12];
    /*0x18*/ int32 textureId; // 1-indexed?
} UnkModelStruct2;

extern int32 DAT_005f0b60;
extern int32 DAT_005f0b64;
extern int32 DAT_005f8c44;
extern int32 DAT_005f8c48;

extern int32 DAT_004ec038;

extern int32 DAT_0051ad84;
extern int32 DAT_0051ad8c;

extern int32 DAT_0051ada4;
extern DDSCAPS2 gDdsCaps2;
extern DWORD gTotalAvailableDisplayMemory;
extern DWORD gFreeDisplayMemory;
extern int32 DAT_008ec0a4;
extern LPDIRECT3D3 gDirect3D3;

extern char *DAT_01b2dda0;
extern UnkTexStruct1 DAT_01b2ea60[2048];

extern D3DTLVERTEX *gVertexQueue;
extern int32 *gTextureQueue;
extern int32 *gRenderFlagQueue;
extern UnkGraphicsStruct4 *gViewportQueue;

extern GUID *gD3DClassID;

extern LPDIRECT3DDEVICE3 gDirect3DDevice3;

extern D3DDEVICEDESC gD3DHardwareFeatures;
extern D3DDEVICEDESC gD3DSoftwareFeatures;

extern int32 gMaxTextureWidth;
extern int32 gMaxTextureHeight;
extern int32 gMinTextureWidth;
extern int32 gMinTextureHeight;

extern UnkD3dStruct1 DAT_01b910e0;

extern D3DVIEWPORT2 gD3DViewport2;
extern LPDIRECT3DVIEWPORT3 g3DViewport;

extern bool32 gZEnable;

extern int32 DAT_0051add8;
extern void *DAT_0051ad80;

extern LPDIRECTDRAWSURFACE4 gZBufferSurface;
extern LPUNKNOWN DAT_0051adc4;

extern int32 DAT_0051ad90;

extern DDPIXELFORMAT DAT_01b91140;

extern int32 DAT_01b2dd80;
extern int32 DAT_01b2dd84;
extern int32 DAT_01b2dd88;
extern int32 DAT_01b2dd8c;

extern int32 DAT_0051ada8;

extern void try_init_zbuffer();
extern int32 FUN_00401af0();
extern int32 FUN_004055c0(int32);
extern void FUN_00409aa0(Matrix3x3 *matrix,int param_2,int index);

// .data

// .bss

// sD3D__try_find_valid_d3d_device
// sDevIsHardware__enum_devices_callback
// sDevIsMonoColor__enum_devices_callback

struct _gD3DGlobals {
    GUID devGuids[MAX_ENUM_DEVICES];
    char devNames[MAX_ENUM_DEVICES][50];
    char devDescriptions[MAX_ENUM_DEVICES][256];
    int32 devCounter;
    int32 selectedDev;
    char padding[8];
    int32 requiredDevBitDepth;
} gD3DGlobals;


// .text

bool32 try_find_valid_d3d_device(HWND hWnd);
HRESULT CALLBACK enum_devices_callback(
    LPGUID lpGUID, 
    LPSTR lpszDeviceDesc, 
    LPSTR lpszDeviceName,
    LPD3DDEVICEDESC lpd3dHWDeviceDesc,
    LPD3DDEVICEDESC lpd3dSWDeviceDesc, 
    LPVOID lpUserArg);
HRESULT CALLBACK enum_zbuffer_formats_callback(LPDDPIXELFORMAT lpDDPixFmt, LPVOID lpContext);

HRESULT CALLBACK enum_pixel_formats_callback(LPDDPIXELFORMAT lpDDPixFmt, LPVOID lpContext) {
    if ((lpDDPixFmt->dwFlags & (DDPF_PALETTEINDEXED4 | DDPF_PALETTEINDEXED8)) == 0 && lpDDPixFmt->dwRGBBitCount == 16) {
        if (lpDDPixFmt->dwRGBAlphaBitMask == 0x8000 &&
            lpDDPixFmt->dwRBitMask == 0x7c00 &&
            lpDDPixFmt->dwGBitMask == 0x3e0 &&
            lpDDPixFmt->dwBBitMask == 0x1f) {
            
            DAT_0051ada4 = 1;
            return D3DENUMRET_CANCEL;
        }

        if (lpDDPixFmt->dwRGBAlphaBitMask == 0 &&
            lpDDPixFmt->dwRBitMask == 0xf800 &&
            lpDDPixFmt->dwGBitMask == 0x7e0 &&
            lpDDPixFmt->dwBBitMask == 0x1f) {
            
            DAT_0051ada4 = 2;
            return D3DENUMRET_CANCEL;
        }
    }

    return D3DENUMRET_OK;
}

int32 get_available_vid_memory() {
    HRESULT result;
    
    memset(&gDdsCaps2, 0, sizeof(DDSCAPS2));

    gDontInitD3D = FALSE;
    gDdsCaps2.dwCaps = DDSCAPS_TEXTURE;

    result = IDirectDraw4_GetAvailableVidMem(
        gDirectDraw4, 
        &gDdsCaps2, 
        &gTotalAvailableDisplayMemory, 
        &gFreeDisplayMemory);
    
    // 12 MiB
    if (gFreeDisplayMemory <= 0xc00000) {
        if (gDirect3D3 != NULL) {
            IDirect3D3_Release(gDirect3D3);
        }
        gDirect3D3 = NULL;

        gD3DDeviceFound = FALSE;
        DAT_008ec0a4 = 0;
        gDontInitD3D = TRUE;
        // Don't think this function is meant to return anything...
        result = 0;
    }

    return result;
}

bool32 FUN_00401100(HWND hWnd) {
    memset(&DAT_01b2ea60, 0, 0x18800*4);
    memset(&DAT_01b2dda0, 0, 0x32b*4);

    gD3DGlobals.requiredDevBitDepth = DDBD_16;

    if (!try_find_valid_d3d_device(hWnd)) {
        gDirect3D3 = NULL;
        return FALSE;
    } else {
        gDirect3D3 = NULL;
        return TRUE;
    }
}

bool32 try_find_valid_d3d_device(HWND hWnd) {
    static LPDIRECT3D sD3D = NULL;

    HRESULT result;
    LPDIRECTDRAW lpDD;

    result = DirectDrawCreate(NULL, &lpDD, NULL);

    if (result != S_OK) {
        display_messagebox("Direct Draw 3D Object Failed");
        return FALSE;
    }

    result = IDirectDraw_QueryInterface(lpDD, &IID_IDirect3D, &sD3D);
    
    if (result != S_OK) {
        display_messagebox("Creation of Direct3D interface failed.");
        return FALSE;
    }

    gD3DGlobals.selectedDev = -1;
    result = IDirect3D_EnumDevices(sD3D, enum_devices_callback, &gD3DGlobals.selectedDev);

    if (result != S_OK) {
        display_messagebox("Enumeration of drivers failed.");
        return FALSE;
    }

    if (gD3DGlobals.devCounter == 0) {
        display_messagebox("Could not find a D3D driver that is compatible with this program.");
        return FALSE;
    }

    IDirect3D_Release(sD3D);
    sD3D = NULL;

    return TRUE;
}

HRESULT CALLBACK enum_devices_callback(
    LPGUID lpGUID, 
    LPSTR lpszDeviceDesc, 
    LPSTR lpszDeviceName,
    LPD3DDEVICEDESC lpd3dHWDeviceDesc,
    LPD3DDEVICEDESC lpd3dSWDeviceDesc,
    LPVOID lpUserArg) {
    
    static bool32 sDevIsHardware = FALSE;
    static bool32 sDevIsMonoColor = FALSE;

    LPD3DDEVICEDESC lpDeviceDesc;
    int32 *lpStartDevice;
    
    lpStartDevice = (int32*)lpUserArg; // lpUserArg == &gD3DGlobals.selectedDev

    // Hardware color model is 0 when there is no hardware support
    lpDeviceDesc = lpd3dHWDeviceDesc->dcmColorModel != 0
        ? lpd3dHWDeviceDesc
        : lpd3dSWDeviceDesc;
    
    // Ensure device renders at the depth we want
    if ((gD3DGlobals.requiredDevBitDepth & lpDeviceDesc->dwDeviceRenderBitDepth) == 0) {
        return D3DENUMRET_OK;
    }

    // Ignore devices with "Emulation" in the name
    if (strstr(lpszDeviceName, "Emulation") == NULL) {
        // Save device info
        memcpy(&gD3DGlobals.devGuids[gD3DGlobals.devCounter], lpGUID, sizeof(GUID));
        lstrcpyA(&gD3DGlobals.devNames[gD3DGlobals.devCounter][0], lpszDeviceName);
        lstrcpyA(&gD3DGlobals.devDescriptions[gD3DGlobals.devCounter][0], lpszDeviceDesc);

        if (*lpStartDevice == -1) {
            // Select the first device we find to start
            gD3DGlobals.selectedDev = gD3DGlobals.devCounter;
            sDevIsHardware = lpDeviceDesc == lpd3dHWDeviceDesc;
            sDevIsMonoColor = (lpDeviceDesc->dcmColorModel & D3DCOLOR_MONO) ? TRUE : FALSE;
        } else if (lpDeviceDesc == lpd3dHWDeviceDesc && !sDevIsHardware) {
            // Prefer hardware over software
            gD3DGlobals.selectedDev = gD3DGlobals.devCounter;
            sDevIsHardware = lpDeviceDesc == lpd3dHWDeviceDesc;
            sDevIsMonoColor = (lpDeviceDesc->dcmColorModel & D3DCOLOR_MONO) ? TRUE : FALSE;
        } else if ((lpDeviceDesc == lpd3dHWDeviceDesc && sDevIsHardware) || (lpDeviceDesc == lpd3dSWDeviceDesc && !sDevIsHardware)) {
            if (lpDeviceDesc->dcmColorModel == D3DCOLOR_RGB && sDevIsMonoColor) {
                // Prefer color over mono
                gD3DGlobals.selectedDev = gD3DGlobals.devCounter;
                sDevIsHardware = lpDeviceDesc == lpd3dHWDeviceDesc;
                sDevIsMonoColor = (lpDeviceDesc->dcmColorModel & D3DCOLOR_MONO) ? TRUE : FALSE;
            }
        }
    
        // Only record hardware devices that can draw primitives, has blending capabilities, and has a depth buffer
        if (sDevIsHardware &&
            (lpd3dHWDeviceDesc->dwDevCaps & D3DDEVCAPS_DRAWPRIMTLVERTEX) != 0 &&
            (lpd3dHWDeviceDesc->dpcTriCaps.dwSrcBlendCaps) != 0 &&
            (lpd3dHWDeviceDesc->dpcTriCaps.dwDestBlendCaps) != 0 &&
            (lpd3dHWDeviceDesc->dwDeviceZBufferBitDepth != 0)) {

            gD3DGlobals.devCounter += 1;
        }
    }

    if (gD3DGlobals.devCounter == MAX_ENUM_DEVICES)
        return D3DENUMRET_CANCEL;
    
    return D3DENUMRET_OK;
}

bool32 init_d3d(HWND hWnd) {
    get_available_vid_memory();

    if (gDontInitD3D) {
        return FALSE;
    }

    if (IDirectDraw4_QueryInterface(gDirectDraw4, &IID_IDirect3D3, &gDirect3D3) != DD_OK) {
        display_messagebox("Creation of Direct3D interface failed.");
        return FALSE;
    } else {
        return TRUE;
    }
}

int32 FUN_004013f0() {
    HRESULT result;
    
    gVertexQueue = custom_alloc(0x180000);
    gTextureQueue = custom_alloc(0x10000);
    gRenderFlagQueue = custom_alloc(0x10000);
    gViewportQueue = custom_alloc(0x40000);

    gD3DClassID = &gD3DGlobals.devGuids[0]; // wtf, why take the first one? this ignores the work enum_devices_callback did
    try_init_zbuffer();

    if (gDDBackBuffer != NULL) {
        result = IDirect3D3_CreateDevice(gDirect3D3, gD3DClassID, gDDBackBuffer, &gDirect3DDevice3, NULL);
    } else {
        result = IDirect3D3_CreateDevice(gDirect3D3, gD3DClassID, gDDFrontBuffer, &gDirect3DDevice3, NULL);
    }

    if (result != D3D_OK) {
        display_messagebox("Failed on Create 3D");
        return FALSE;
    }

    memset(&gD3DHardwareFeatures, 0, sizeof(D3DDEVICEDESC));
    memset(&gD3DSoftwareFeatures, 0, sizeof(D3DDEVICEDESC));

    gD3DHardwareFeatures.dwSize = D3DDEVICEDESCSIZE;
    gD3DSoftwareFeatures.dwSize = D3DDEVICEDESCSIZE;

    IDirect3DDevice3_GetCaps(gDirect3DDevice3, &gD3DHardwareFeatures, &gD3DSoftwareFeatures);

    gMaxTextureWidth = gD3DHardwareFeatures.dwMaxTextureWidth;
    gMaxTextureHeight = gD3DHardwareFeatures.dwMaxTextureHeight;
    gMinTextureWidth = gD3DHardwareFeatures.dwMinTextureWidth;
    gMinTextureHeight = gD3DHardwareFeatures.dwMinTextureHeight;

    if (gMaxTextureWidth > 128) {
        gMaxTextureWidth = 128;
    }
    if (gMaxTextureHeight > 256) {
        gMaxTextureHeight = 256;
    }
    if (gMaxTextureWidth < 128) {
        gMaxTextureWidth = 128;
    }
    if (gMaxTextureHeight < 128) {
        gMaxTextureHeight = 128;
    }
    if (gMinTextureWidth < 128) {
        gMinTextureWidth = 128;
    }
    if (gMinTextureHeight < 128) {
        gMinTextureHeight = 128;
    }

    memset(&gD3DViewport2, 0, sizeof(D3DVIEWPORT2));
    gD3DViewport2.dwSize = sizeof(D3DVIEWPORT2);
    gD3DViewport2.dwWidth = gDisplayWidth;
    gD3DViewport2.dwHeight = gDisplayHeight;
    gD3DViewport2.dvMaxZ = 1.0f;
    gD3DViewport2.dvClipX = -1.0f;
    gD3DViewport2.dvClipWidth = 2.0f;
    gD3DViewport2.dvClipY = 1.0f;
    gD3DViewport2.dvClipHeight = 2.0f;

    memset(&DAT_01b910e0, 0, sizeof(UnkD3dStruct1));
    DAT_01b910e0.dwSize = sizeof(UnkD3dStruct1);
    DAT_01b910e0.unk0x14 = 256.0f;
    DAT_01b910e0.unk0x4 = 256.0f;
    DAT_01b910e0.unk0x18 = 256.0f;
    DAT_01b910e0.unk0x8 = 256.0f;
    DAT_01b910e0.unk0x1c = 256.0f;
    DAT_01b910e0.unk0xc = 256.0f;
    DAT_01b910e0.unk0x4c = 16;

    if (IDirect3D3_CreateViewport(gDirect3D3, &g3DViewport, NULL) != D3D_OK) {
        display_messagebox("Failed on viewport");
        return FALSE;
    }

    if (IDirect3DDevice3_AddViewport(gDirect3DDevice3, g3DViewport) != D3D_OK) {
        display_messagebox("Failed on add viewport");
        return FALSE;
    }

    if (IDirect3DViewport3_SetViewport2(g3DViewport, &gD3DViewport2) != D3D_OK) {
        display_messagebox("Failed on setviewport2");
        return FALSE;
    }

    if (IDirect3DDevice3_SetCurrentViewport(gDirect3DDevice3, g3DViewport) != D3D_OK) {
        display_messagebox("Failed on set current viewport");
        return FALSE;
    }

    if (gZEnable) {
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZENABLE, D3DZB_TRUE);
    } else {
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZENABLE, D3DZB_FALSE);
    }
    IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZFUNC, D3DCMP_LESS);
    
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 1, D3DTSS_COLOROP, D3DTOP_DISABLE);
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 2, D3DTSS_COLOROP, D3DTOP_DISABLE);
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 3, D3DTSS_COLOROP, D3DTOP_DISABLE);
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 4, D3DTSS_COLOROP, D3DTOP_DISABLE);
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 5, D3DTSS_COLOROP, D3DTOP_DISABLE);
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 6, D3DTSS_COLOROP, D3DTOP_DISABLE);
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 7, D3DTSS_COLOROP, D3DTOP_DISABLE);
    
    IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_TEXTUREPERSPECTIVE, TRUE);

    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MINFILTER, D3DTFN_ANISOTROPIC);
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MAGFILTER, D3DTFG_ANISOTROPIC);
    IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_ADDRESS, D3DTADDRESS_WRAP);

    IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_SPECULARENABLE, TRUE);
    IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_CULLMODE, D3DCULL_CW);
    IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_COLORKEYENABLE, TRUE);

    DAT_0051ada4 = 0;
    IDirect3DDevice3_EnumTextureFormats(gDirect3DDevice3, enum_pixel_formats_callback, NULL);

    memset(&gDdsCaps2, 0, sizeof(DDSCAPS2));
    gDdsCaps2.dwCaps = DDSCAPS_TEXTURE;

    IDirectDraw4_GetAvailableVidMem(gDirectDraw4, &gDdsCaps2, &gTotalAvailableDisplayMemory, &gFreeDisplayMemory);

    DAT_0051add8 = 0;

    if (gFreeDisplayMemory >= 0x1efe920) { // >= 30.99 MiB
        DAT_0051add8 = 1;
    } else if (gFreeDisplayMemory <= 0x1300000) { // <= 19 MiB
        DAT_0051add8 = 2;
    } else if (gFreeDisplayMemory <= 0xe00000) { // <= 14 MiB
        DAT_0051add8 = 3;
    }

    return TRUE;
}

int32 FUN_00401870(HWND hWnd) {
    DWORD tickStart;

    tickStart = GetTickCount();
    while ((GetTickCount() - tickStart) < 128) { }

    if (gD3DDeviceFound != 0) {
        FUN_00401af0();
    } else {
        FUN_00401b40();
    }

    if (gVertexQueue != NULL) {
        custom_free(&gVertexQueue);
    }
    if (gTextureQueue != NULL) {
        custom_free(&gTextureQueue);
    }
    if (gRenderFlagQueue != NULL) {
        custom_free(&gRenderFlagQueue);
    }
    if (gViewportQueue != NULL) {
        custom_free(&gViewportQueue);
    }
    if (DAT_0051ad80 != NULL) {
        custom_free(&DAT_0051ad80);
    }

    DAT_0051ad80 = NULL;
    gVertexQueue = NULL;
    gRenderFlagQueue = NULL;
    gTextureQueue = NULL;
    gViewportQueue = NULL;

    if (gZBufferSurface != NULL) {
        IDirectDrawSurface4_Release(gZBufferSurface);
    }
    gZBufferSurface = NULL;

    if (DAT_0051adc4 != NULL) {
        (DAT_0051adc4)->lpVtbl->Release(DAT_0051adc4);
    }
    DAT_0051adc4 = NULL;

    if (g3DViewport != NULL) {
        IDirect3DViewport3_Release(g3DViewport);
    }
    g3DViewport = NULL;

    if (gDirect3DDevice3 != NULL) {
        IDirect3DDevice3_Release(gDirect3DDevice3);
    }
    gDirect3DDevice3 = NULL;

    if (gDirect3D3 != NULL) {
        IDirect3D3_Release(gDirect3D3);
    }
    gDirect3D3 = NULL;

    gVertexCount = 0;

    return 0;
}

void FUN_004019b0(int32 param1) {
    int32 i;
    int32 index;

    index = param1 - 1;
    if (index < 0) {
        return;
    }

    if (DAT_01b2ea60[index].unk0xc0 != NULL) {
        custom_free(&DAT_01b2ea60[index].unk0xc0);
    }
    DAT_01b2ea60[index].unk0xc0 = NULL;

    if (DAT_01b2ea60[index].texture != NULL) {
        IDirect3DTexture2_Release(DAT_01b2ea60[index].texture);
    }
    DAT_01b2ea60[index].texture = NULL;

    if (DAT_01b2ea60[index].surface != NULL) {
        IDirectDrawSurface4_Release(DAT_01b2ea60[index].surface);
    }
    DAT_01b2ea60[index].surface = NULL;

    for (i = 1; i < (DAT_01b2ea60[index].unk0x2c * DAT_01b2ea60[index].unk0x30); i++) {
        FUN_004019b0(DAT_01b2ea60[index].unk0x34[i] + 1);
    }
}

void FUN_00401a60(int32 param1) {
    int32 i;
    int32 index;

    index = param1 - 1;
    if (index < 0) {
        return;
    }

    if (DAT_01b2ea60[index].texture != NULL) {
        IDirect3DTexture2_Release(DAT_01b2ea60[index].texture);
    }
    DAT_01b2ea60[index].texture = NULL;

    if (DAT_01b2ea60[index].surface != NULL) {
        IDirectDrawSurface4_Release(DAT_01b2ea60[index].surface);
    }
    DAT_01b2ea60[index].surface = NULL;

    for (i = 1; i < (DAT_01b2ea60[index].unk0x2c * DAT_01b2ea60[index].unk0x30); i++) {
        FUN_00401a60(DAT_01b2ea60[index].unk0x34[i] + 1);
    }
}

int32 FUN_00401af0() {
    DWORD tickStart;
    int32 i;

    tickStart = GetTickCount();
    while ((GetTickCount() - tickStart) < 128) { }

    for (i = 0; i < 2048; i++) {
        FUN_00401a60(i + 1);
    }

    gVertexCount = 0;
    
    return 1;
}

int32 FUN_00401b40() {
    DWORD tickStart;
    int32 i;

    tickStart = GetTickCount();
    while ((GetTickCount() - tickStart) < 128) { }

    for (i = 0; i < 2048; i++) {
        FUN_004019b0(i + 1);
    }

    gVertexCount = 0;
    
    return 1;
}

void FUN_00401b90(int32 vertCount) {
    DWORD lastViewportTop;
    DWORD lastViewportLeft;
    DWORD lastViewportRight;
    DWORD lastViewportBottom;

    int32 lower4Bits;
    int32 fifthBit;
    int32 lastLower4Bits;
    int32 lastFifthBit;

    int32 index;
    int32 triangleCount;

    int32 textureIndex;
    int32 lastTextureIndex;

    int32 primTriCount;

    memset(&gD3DViewport2, 0, sizeof(D3DVIEWPORT2));
    gD3DViewport2.dwSize = sizeof(D3DVIEWPORT2);
    gD3DViewport2.dwX = 0;
    gD3DViewport2.dwY = 0;
    gD3DViewport2.dwWidth = gDisplayWidth;
    gD3DViewport2.dwHeight = gDisplayHeight;
    gD3DViewport2.dvMaxZ = 1.0f;
    gD3DViewport2.dvClipX = -1.0f;
    gD3DViewport2.dvClipY = 1.0f;
    gD3DViewport2.dvClipHeight = 2.0f;
    gD3DViewport2.dvClipWidth = 2.0f;

    IDirect3DViewport2_SetViewport2(g3DViewport, &gD3DViewport2);

    lastViewportLeft = 0;
    lastViewportTop = 0;
    lastViewportRight = gDisplayWidth;
    lastViewportBottom = gDisplayHeight;

    IDirect3DDevice3_BeginScene(gDirect3DDevice3);

    lastLower4Bits = -1;
    lastFifthBit = -1;

    DAT_01b18068 = 0.95f;
    DAT_0051ad90 = 0;

    lastTextureIndex = -2;

    triangleCount = vertCount / 3;
    index = 0;

    while (index < triangleCount) {
        lower4Bits = gRenderFlagQueue[index] & 0xf;
        fifthBit = gRenderFlagQueue[index] & 0x10;

        if (lower4Bits == 3 || lower4Bits == 5) {
            index += 1;
            continue;
        }

        if (lastViewportLeft != gViewportQueue[index].left ||
            lastViewportTop != gViewportQueue[index].top ||
            lastViewportRight != gViewportQueue[index].right ||
            lastViewportBottom != gViewportQueue[index].bottom) {

            IDirect3DDevice3_EndScene(gDirect3DDevice3);

            memset(&gD3DViewport2, 0, sizeof(gD3DViewport2));
            gD3DViewport2.dwSize = sizeof(D3DVIEWPORT2);
            gD3DViewport2.dwX = gViewportQueue[index].left;
            gD3DViewport2.dwY = gViewportQueue[index].top;
            gD3DViewport2.dwWidth = gViewportQueue[index].right - gViewportQueue[index].left;
            gD3DViewport2.dwHeight = gViewportQueue[index].bottom - gViewportQueue[index].top;
            gD3DViewport2.dvMaxZ = 1.0f;
            gD3DViewport2.dvClipX = -1.0f;
            gD3DViewport2.dvClipY = 1.0f;
            gD3DViewport2.dvClipHeight = 2.0f;
            gD3DViewport2.dvClipWidth = 2.0f;

            IDirect3DViewport2_SetViewport2(g3DViewport, &gD3DViewport2);

            lastViewportLeft = gViewportQueue[index].left;
            lastViewportTop = gViewportQueue[index].top;
            lastViewportRight = gViewportQueue[index].right;
            lastViewportBottom = gViewportQueue[index].bottom;

            IDirect3DDevice3_BeginScene(gDirect3DDevice3);
        }

        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ALPHABLENDENABLE, TRUE);
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_TEXTUREMAPBLEND, D3DTBLEND_MODULATEALPHA);
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ALPHATESTENABLE, FALSE);
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_SRCBLEND, D3DBLEND_SRCALPHA);
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_DESTBLEND, D3DBLEND_INVSRCALPHA);

        if (lower4Bits == 4 && lastLower4Bits != 4) {
            IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_ADDRESS, D3DTADDRESS_WRAP);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_SPECULARENABLE, FALSE);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZFUNC, D3DCMP_EQUAL);
            lastLower4Bits = lower4Bits;
        } else if (lower4Bits == 2 && lastLower4Bits != 2) {
            IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_ADDRESS, D3DTADDRESS_CLAMP);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_SPECULARENABLE, TRUE);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZFUNC, D3DCMP_LESSEQUAL);
            lastLower4Bits = lower4Bits;
        } else if ((lower4Bits == 4 && lastLower4Bits == 4) || (lower4Bits != 4 && (lower4Bits != 2 || lastLower4Bits == 2))) {
            IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_ADDRESS, D3DTADDRESS_CLAMP);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_SPECULARENABLE, TRUE);
            if (gZEnable) {
                IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZENABLE, TRUE);
            }
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZFUNC, D3DCMP_LESS);
            lastLower4Bits = lower4Bits;
        }

        textureIndex = gTextureQueue[index];
        if (textureIndex != lastTextureIndex) {
            if (textureIndex >= 0) {
                lastTextureIndex = textureIndex;
                if (DAT_01b2ea60[textureIndex].texture != NULL) {
                    IDirect3DDevice3_SetTexture(gDirect3DDevice3, 0, DAT_01b2ea60[textureIndex].texture);
                } else {
                    IDirect3DDevice3_SetTexture(gDirect3DDevice3, 0, NULL);
                }
            } else {
                if (gTextureQueue[index] != lastTextureIndex) {
                    lastTextureIndex = textureIndex;
                    IDirect3DDevice3_SetTexture(gDirect3DDevice3, 0, NULL);
                }
            }
            
        }

        if (fifthBit != lastFifthBit) {
            if (fifthBit != 0) {
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MINFILTER, D3DTFN_POINT);
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MAGFILTER, D3DTFG_POINT);
                IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_EDGEANTIALIAS, FALSE);
                IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ANTIALIAS, D3DANTIALIAS_NONE);
                IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_DITHERENABLE, FALSE);
            } else {
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MINFILTER, D3DTFN_LINEAR);
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MAGFILTER, D3DTFG_LINEAR);
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MIPFILTER, D3DTFP_LINEAR);
            }

            lastFifthBit = fifthBit;
        }

        for (primTriCount = 0; (primTriCount + index) < triangleCount; primTriCount++) {
            if ((gRenderFlagQueue[primTriCount + index] !=  gRenderFlagQueue[index]) ||
                (gTextureQueue[primTriCount + index] != lastTextureIndex) ||
                    (gViewportQueue[primTriCount + index].left != lastViewportLeft ||
                    gViewportQueue[primTriCount + index].top != lastViewportTop ||
                    gViewportQueue[primTriCount + index].right != lastViewportRight ||
                    gViewportQueue[primTriCount + index].bottom != lastViewportBottom)) {
                break;
            }
        }

        // Renders 3D stuff, excluding fog of war edges
        IDirect3DDevice3_DrawPrimitive(gDirect3DDevice3, 
            /*dptPrimitiveType*/ D3DPT_TRIANGLELIST, 
            /*dwVertexTypeDesc*/ D3DFVF_TLVERTEX, 
            /*lpvVertices*/ &gVertexQueue[index * 3], 
            /*dwVertexCount*/ primTriCount * 3, 
            /*dwFlags*/ D3DDP_DONOTUPDATEEXTENTS | D3DDP_DONOTLIGHT);
        
        index += primTriCount;
    }

    index = 0;

    while (index < triangleCount) {
        lower4Bits = gRenderFlagQueue[index] & 0xf;
        fifthBit = gRenderFlagQueue[index] & 0x10;

        if (lower4Bits != 3 && lower4Bits != 5) {
            index += 1;
            continue;
        }

        if (lastViewportLeft != gViewportQueue[index].left ||
            lastViewportTop != gViewportQueue[index].top ||
            lastViewportRight != gViewportQueue[index].right ||
            lastViewportBottom != gViewportQueue[index].bottom) {

            IDirect3DDevice3_EndScene(gDirect3DDevice3);

            memset(&gD3DViewport2, 0, sizeof(gD3DViewport2));
            gD3DViewport2.dwSize = sizeof(D3DVIEWPORT2);
            gD3DViewport2.dwX = gViewportQueue[index].left;
            gD3DViewport2.dwY = gViewportQueue[index].top;
            gD3DViewport2.dwWidth = gViewportQueue[index].right - gViewportQueue[index].left;
            gD3DViewport2.dwHeight = gViewportQueue[index].bottom - gViewportQueue[index].top;
            gD3DViewport2.dvMaxZ = 1.0f;
            gD3DViewport2.dvClipX = -1.0f;
            gD3DViewport2.dvClipY = 1.0f;
            gD3DViewport2.dvClipHeight = 2.0f;
            gD3DViewport2.dvClipWidth = 2.0f;

            IDirect3DViewport2_SetViewport2(g3DViewport, &gD3DViewport2);

            lastViewportLeft = gViewportQueue[index].left;
            lastViewportTop = gViewportQueue[index].top;
            lastViewportRight = gViewportQueue[index].right;
            lastViewportBottom = gViewportQueue[index].bottom;

            IDirect3DDevice3_BeginScene(gDirect3DDevice3);
        }

        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ALPHABLENDENABLE, TRUE);
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_TEXTUREMAPBLEND, D3DTBLEND_MODULATEALPHA);
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ALPHATESTENABLE, FALSE);
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_SRCBLEND, D3DBLEND_SRCALPHA);
        IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_DESTBLEND, D3DBLEND_INVSRCALPHA);

        if (lower4Bits == 3 && lastLower4Bits != 3) {
            IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_ADDRESS, D3DTADDRESS_CLAMP);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_SPECULARENABLE, TRUE);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZFUNC, D3DCMP_LESSEQUAL);
            lastLower4Bits = lower4Bits;
        } else if (lower4Bits == 5 && lastLower4Bits != 5) {
            IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_ADDRESS, D3DTADDRESS_CLAMP);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_SPECULARENABLE, TRUE);
            IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ZFUNC, D3DCMP_LESSEQUAL);
            lastLower4Bits = lower4Bits;
        }

        textureIndex = gTextureQueue[index];
        if (textureIndex != lastTextureIndex) {
            if (textureIndex >= 0) {
                lastTextureIndex = textureIndex;
                if (DAT_01b2ea60[textureIndex].texture != NULL) {
                    IDirect3DDevice3_SetTexture(gDirect3DDevice3, 0, DAT_01b2ea60[textureIndex].texture);
                } else {
                    IDirect3DDevice3_SetTexture(gDirect3DDevice3, 0, NULL);
                }
            } else {
                if (gTextureQueue[index] != lastTextureIndex) {
                    lastTextureIndex = textureIndex;
                    IDirect3DDevice3_SetTexture(gDirect3DDevice3, 0, NULL);
                }
            }
            
        }

        if (fifthBit != lastFifthBit) {
            if (fifthBit != 0) {
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MINFILTER, D3DTFN_POINT);
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MAGFILTER, D3DTFG_POINT);
                IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_EDGEANTIALIAS, FALSE);
                IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_ANTIALIAS, D3DANTIALIAS_NONE);
                IDirect3DDevice3_SetRenderState(gDirect3DDevice3, D3DRENDERSTATE_DITHERENABLE, FALSE);
            } else {
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MINFILTER, D3DTFN_LINEAR);
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MAGFILTER, D3DTFG_LINEAR);
                IDirect3DDevice3_SetTextureStageState(gDirect3DDevice3, 0, D3DTSS_MIPFILTER, D3DTFP_LINEAR);
            }

            lastFifthBit = fifthBit;
        }

        for (primTriCount = 0; (primTriCount + index) < triangleCount; primTriCount++) {
            if ((gRenderFlagQueue[primTriCount + index] !=  gRenderFlagQueue[index]) ||
                (gTextureQueue[primTriCount + index] != lastTextureIndex) ||
                    (gViewportQueue[primTriCount + index].left != lastViewportLeft ||
                    gViewportQueue[primTriCount + index].top != lastViewportTop ||
                    gViewportQueue[primTriCount + index].right != lastViewportRight ||
                    gViewportQueue[primTriCount + index].bottom != lastViewportBottom)) {
                break;
            }
        }

        // Seems to just render fog of war edges
        IDirect3DDevice3_DrawPrimitive(gDirect3DDevice3, 
            /*dptPrimitiveType*/ D3DPT_TRIANGLELIST, 
            /*dwVertexTypeDesc*/ D3DFVF_TLVERTEX, 
            /*lpvVertices*/ &gVertexQueue[index * 3], 
            /*dwVertexCount*/ primTriCount * 3, 
            /*dwFlags*/ D3DDP_DONOTUPDATEEXTENTS | D3DDP_DONOTLIGHT);
        
        index += primTriCount;
    }

    IDirect3DDevice3_EndScene(gDirect3DDevice3);
}

void FUN_00402470(UnkModelStruct* param1, UnkModelStruct2* param2) {
    int32 triangleCount;

    float32 tuDivisor;
    float32 tvDivisor;

    float32 color_r;
    float32 color_g;
    float32 color_b;
    float32 color_a;

    float32 spec_r;
    float32 spec_g;
    float32 spec_b;
    float32 spec_a;

    triangleCount = gVertexCount / 3;
    if (triangleCount >= 16384) {
        return;
    }

    gViewportQueue[triangleCount].left = DAT_005f0b64;
    gViewportQueue[triangleCount].top = DAT_005f0b60;
    gViewportQueue[triangleCount].right = DAT_005f8c48;
    gViewportQueue[triangleCount].bottom = DAT_005f8c44;

    gVertexQueue[gVertexCount + 0].sx = param1->x1;
    gVertexQueue[gVertexCount + 0].sy = param1->y1;
    gVertexQueue[gVertexCount + 0].sz = param1->z1 / 32768 + DAT_01b18068;
    gVertexQueue[gVertexCount + 0].rhw = 1.0f;

    gVertexQueue[gVertexCount + 1].sx = param1->x2;
    gVertexQueue[gVertexCount + 1].sy = param1->y2;
    gVertexQueue[gVertexCount + 1].sz = param1->z2 / 32768 + DAT_01b18068;
    gVertexQueue[gVertexCount + 1].rhw = 1.0f;

    gVertexQueue[gVertexCount + 2].sx = param1->x3;
    gVertexQueue[gVertexCount + 2].sy = param1->y3;
    gVertexQueue[gVertexCount + 2].sz = param1->z3 / 32768 + DAT_01b18068;
    gVertexQueue[gVertexCount + 2].rhw = 1.0f;

    gTextureQueue[triangleCount] = param2->textureId - 1;

    gRenderFlagQueue[triangleCount] = 0;

    if (gTextureQueue[gVertexCount / 3] >= 0) {
        tuDivisor = DAT_01b2ea60[gTextureQueue[triangleCount] & 0xffff].widthMultipleOfMin - 1.0;
        tvDivisor = DAT_01b2ea60[gTextureQueue[triangleCount] & 0xffff].heightMultipleOfMin - 1.0;

        gVertexQueue[gVertexCount + 0].tu = (float32)(param1->tu1 + 0.5) / tuDivisor;
        gVertexQueue[gVertexCount + 0].tv = (float32)(param1->tv1 + 0.5) / tvDivisor;
        gVertexQueue[gVertexCount + 1].tu = (float32)(param1->tu2 + 0.5) / tuDivisor;
        gVertexQueue[gVertexCount + 1].tv = (float32)(param1->tv2 + 0.5) / tvDivisor;
        gVertexQueue[gVertexCount + 2].tu = (float32)(param1->tu3 + 0.5) / tuDivisor;
        gVertexQueue[gVertexCount + 2].tv = (float32)(param1->tv3 + 0.5) / tvDivisor;
    } else {
        gVertexQueue[gVertexCount + 0].tu = 0.0f;
        gVertexQueue[gVertexCount + 0].tv = 0.0f;
        gVertexQueue[gVertexCount + 1].tu = 0.0f;
        gVertexQueue[gVertexCount + 1].tv = 0.0f;
        gVertexQueue[gVertexCount + 2].tu = 0.0f;
        gVertexQueue[gVertexCount + 2].tv = 0.0f;
    }

    if (param1->unk0x108 == 0 || param1->unk0x1 == 0) {
        gTextureQueue[triangleCount] = -1;
    }

    if (DAT_0051ad8c == 0) {
        gRenderFlagQueue[triangleCount] = 5;
    } else {
        gRenderFlagQueue[triangleCount] = 2;
    }

    if (param1->unk0x2 & 0x800) {
        color_a = 0.15f;
    } else if (DAT_0051ad8c != 0) {
        color_a = 0.8f;
    } else {
        color_a = 0.4f;
    }

    spec_a = DAT_0051ad8c * 0.00062499999f + 0.2;

    spec_r = 0.0;
    spec_g = 0.0;
    spec_b = 0.0;
    
    color_r = param1->unk0xc4 * 0.0035714286f;
    color_g = param1->unk0xcc * 0.0035714286f;
    color_b = param1->unk0xd4 * 0.0035714286f;

    if (DAT_0051ad84 != 0) {
        color_r = color_r - 0.6;
        color_g = color_g - 0.4;
        color_b = color_b - 0.1;
    }

    if (color_r > 1.0) {
        spec_r = (color_r - 1.0) * 0.6666666666666666;
        color_r = 1;
    } else if (color_r < 0.0) {
        color_r = 0.0;
    }

    if (color_g > 1.0) {
        spec_g = (color_g - 1.0) * 0.6666666666666666;
        color_g = 1;
    } else if (color_g < 0.0) {
        color_g = 0.0;
    }

    if (color_b > 1.0) {
        spec_b = (color_b - 1.0) * 0.6666666666666666;
        color_b = 1;
    } else if (color_b < 0.0) {
        color_b = 0.0;
    }

    gVertexQueue[gVertexCount + 0].color = D3DRGBA(color_r, color_g, color_b, color_a);
    gVertexQueue[gVertexCount + 0].specular = D3DRGBA(spec_r, spec_g, spec_b, spec_a);

    spec_r = 0.0;
    spec_g = 0.0;
    spec_b = 0.0;

    color_r = param1->unk0xc6 * 0.0035714286f;
    color_g = param1->unk0xce * 0.0035714286f;
    color_b = param1->unk0xd6 * 0.0035714286f;

    if (DAT_0051ad84 != 0) {
        color_r = color_r - 0.6;
        color_g = color_g - 0.4;
        color_b = color_b - 0.1;
    }

    if (color_r > 1.0) {
        spec_r = (color_r - 1.0) * 0.6666666666666666;
        color_r = 1;
    } else if (color_r < 0.0) {
        color_r = 0.0;
    }

    if (color_g > 1.0) {
        spec_g = (color_g - 1.0) * 0.6666666666666666;
        color_g = 1;
    } else if (color_g < 0.0) {
        color_g = 0.0;
    }

    if (color_b > 1.0) {
        spec_b = (color_b - 1.0) * 0.6666666666666666;
        color_b = 1;
    } else if (color_b < 0.0) {
        color_b = 0.0;
    }

    gVertexQueue[gVertexCount + 1].color = D3DRGBA(color_r, color_g, color_b, color_a);
    gVertexQueue[gVertexCount + 1].specular = D3DRGBA(spec_r, spec_g, spec_b, spec_a);

    spec_r = 0.0;
    spec_g = 0.0;
    spec_b = 0.0;

    color_r = param1->unk0xc8 * 0.0035714286f;
    color_g = param1->unk0xd0 * 0.0035714286f;
    color_b = param1->unk0xd8 * 0.0035714286f;

    if (DAT_0051ad84 != 0) {
        color_r = color_r - 0.6;
        color_g = color_g - 0.4;
        color_b = color_b - 0.1;
    }

    if (color_r > 1.0) {
        spec_r = (color_r - 1.0) * 0.6666666666666666;
        color_r = 1;
    } else if (color_r < 0.0) {
        color_r = 0.0;
    }

    if (color_g > 1.0) {
        spec_g = (color_g - 1.0) * 0.6666666666666666;
        color_g = 1;
    } else if (color_g < 0.0) {
        color_g = 0.0;
    }

    if (color_b > 1.0) {
        spec_b = (color_b - 1.0) * 0.6666666666666666;
        color_b = 1;
    } else if (color_b < 0.0) {
        color_b = 0.0;
    }

    gVertexQueue[gVertexCount + 2].color = D3DRGBA(color_r, color_g, color_b, color_a);
    gVertexQueue[gVertexCount + 2].specular = D3DRGBA(spec_r, spec_g, spec_b, spec_a);

    if ((param1->unk0x2 & 0x200) != 0) {
        gRenderFlagQueue[triangleCount] |= 0x10;
    }

    gVertexCount += 3;
}

// Appears to add triangles for drawing shadows
void FUN_00402e30(UnkModelStruct* param1, int32 param2, UnkModelStruct2* param3) {
    int32 triangleCount;

    float32 tuDivisor;
    float32 tvDivisor;

    D3DCOLOR color;
    D3DCOLOR specular;

    triangleCount = gVertexCount / 3;
    if (triangleCount >= 16384) {
        return;
    }

    gViewportQueue[triangleCount].left = DAT_005f0b64;
    gViewportQueue[triangleCount].top = DAT_005f0b60;
    gViewportQueue[triangleCount].right = DAT_005f8c48;
    gViewportQueue[triangleCount].bottom = DAT_005f8c44;

    gVertexQueue[gVertexCount + 0].sx = param1->x1;
    gVertexQueue[gVertexCount + 0].sy = param1->y1;
    gVertexQueue[gVertexCount + 0].sz = param1->z1 / 32768 + DAT_01b18068;
    gVertexQueue[gVertexCount + 0].rhw = 1.0f;

    gVertexQueue[gVertexCount + 1].sx = param1->x2;
    gVertexQueue[gVertexCount + 1].sy = param1->y2;
    gVertexQueue[gVertexCount + 1].sz = param1->z2 / 32768 + DAT_01b18068;
    gVertexQueue[gVertexCount + 1].rhw = 1.0f;

    gVertexQueue[gVertexCount + 2].sx = param1->x3;
    gVertexQueue[gVertexCount + 2].sy = param1->y3;
    gVertexQueue[gVertexCount + 2].sz = param1->z3 / 32768 + DAT_01b18068;
    gVertexQueue[gVertexCount + 2].rhw = 1.0f;

    gRenderFlagQueue[triangleCount] = 1;

    if (param1->unk0x108 != param3->unk0x0) {
        gTextureQueue[triangleCount] = FUN_004055c0(param1->unk0x108);
    } else {
        gTextureQueue[triangleCount] = param3->textureId - 1;
    }

    if (gTextureQueue[triangleCount] >= 0) {
        tuDivisor = DAT_01b2ea60[gTextureQueue[triangleCount]].widthMultipleOfMin - 1.0;
        tvDivisor = DAT_01b2ea60[gTextureQueue[triangleCount]].heightMultipleOfMin - 1.0;

        gVertexQueue[gVertexCount + 0].tu = (float32)(param1->tu1 + 0.5) / tuDivisor;
        gVertexQueue[gVertexCount + 0].tv = (float32)(param1->tv1 + 0.5) / tvDivisor;
        gVertexQueue[gVertexCount + 1].tu = (float32)(param1->tu2 + 0.5) / tuDivisor;
        gVertexQueue[gVertexCount + 1].tv = (float32)(param1->tv2 + 0.5) / tvDivisor;
        gVertexQueue[gVertexCount + 2].tu = (float32)(param1->tu3 + 0.5) / tuDivisor;
        gVertexQueue[gVertexCount + 2].tv = (float32)(param1->tv3 + 0.5) / tvDivisor;
    } else {
        gVertexQueue[gVertexCount + 0].tu = 0.0f;
        gVertexQueue[gVertexCount + 0].tv = 0.0f;
        gVertexQueue[gVertexCount + 1].tu = 0.0f;
        gVertexQueue[gVertexCount + 1].tv = 0.0f;
        gVertexQueue[gVertexCount + 2].tu = 0.0f;
        gVertexQueue[gVertexCount + 2].tv = 0.0f;
    }

    color = D3DRGBA(0.25, 0.25, 0.25, 0.1f - param2 * 0.04f);
    specular = D3DRGBA(0, 0, 0, 0);

    gVertexQueue[gVertexCount + 0].color = color;
    gVertexQueue[gVertexCount + 0].specular = specular;
    gVertexQueue[gVertexCount + 1].color = color;
    gVertexQueue[gVertexCount + 1].specular = specular;
    gVertexQueue[gVertexCount + 2].color = color;
    gVertexQueue[gVertexCount + 2].specular = specular;

    if (param1->unk0x108 == 0 || param1->unk0x1 == 0) {
        gTextureQueue[triangleCount] = -1;
    }

    if (DAT_004ec038 == 0) {
        gRenderFlagQueue[triangleCount] = 2;
    }

    if ((param1->unk0x2 & 0x200) != 0) {
        gRenderFlagQueue[triangleCount] |= 0x10;
    }

    gVertexCount += 3;
}

// Loads textures for 3D models
int FUN_00403260(char *texPath, uint16 *texBytes, int32 width, int32 height, int32 textureId) {
    int32 widthMultipleOfMin;
    int32 heightMultipleOfMin;

    int32 texturePageIdx;

    DDSURFACEDESC2 surfaceDesc;
    DDSURFACEDESC2 surfaceDesc2;

    int32 width2;
    int32 width3;
    int32 height2;
    int32 height3;

    DDCOLORKEY colorKey;

    widthMultipleOfMin = ((gMinTextureWidth - 1 + width) / gMinTextureWidth) * gMinTextureWidth;
    heightMultipleOfMin = ((gMinTextureHeight - 1 + width) / gMinTextureHeight) * gMinTextureHeight;

    if (widthMultipleOfMin > gMaxTextureWidth) {
        widthMultipleOfMin = gMaxTextureWidth;
    }

    if (heightMultipleOfMin > gMaxTextureHeight) {
        heightMultipleOfMin = gMaxTextureHeight;
    }

    texturePageIdx = textureId - 1;
    if (texturePageIdx <= 0) {
        texturePageIdx = 0;

        while (texturePageIdx < 2048) {
            if (DAT_01b2ea60[texturePageIdx].texture == NULL && DAT_01b2ea60[texturePageIdx].unk0xc0 == NULL) {
                break;
            }

            texturePageIdx++;
        }

        if (texturePageIdx >= 2048) {
            display_messagebox("No more Texture pages available.");
        }

        DAT_01b2ea60[texturePageIdx].width = width;
        DAT_01b2ea60[texturePageIdx].height = height;
        DAT_01b2ea60[texturePageIdx].widthMultipleOfMin = widthMultipleOfMin;
        DAT_01b2ea60[texturePageIdx].heightMultipleOfMin = heightMultipleOfMin;
        DAT_01b2ea60[texturePageIdx].texBytes = texBytes;
        DAT_01b2ea60[texturePageIdx].unk0xbc = textureId; // TODO: this might not be right
        DAT_01b2ea60[texturePageIdx].unk0x24 = 0;
        DAT_01b2ea60[texturePageIdx].unk0xc0 = NULL;
        DAT_01b2ea60[texturePageIdx].unk0x28 = 0;
        DAT_01b2ea60[texturePageIdx].unk0x2c = 0;
        DAT_01b2ea60[texturePageIdx].unk0x30 = 0;

        memset(&surfaceDesc, 0, sizeof(DDSURFACEDESC2));
        surfaceDesc.dwSize = sizeof(DDSURFACEDESC2);

        memset(&surfaceDesc.ddpfPixelFormat, 0, sizeof(DDPIXELFORMAT));
        surfaceDesc.ddpfPixelFormat.dwSize = sizeof(DDPIXELFORMAT);

        surfaceDesc.ddpfPixelFormat.dwFlags = DDPF_RGB;
        surfaceDesc.ddpfPixelFormat.dwFourCC = 0;
        surfaceDesc.ddpfPixelFormat.dwRGBBitCount = 16;
        if (DAT_0051ada4 == 1) {
            surfaceDesc.ddpfPixelFormat.dwRBitMask = 0x7c00;
            surfaceDesc.ddpfPixelFormat.dwGBitMask = 0x03e0;
            surfaceDesc.ddpfPixelFormat.dwBBitMask = 0x001f;
            surfaceDesc.ddpfPixelFormat.dwRGBAlphaBitMask = 0x8000;
        } else if (DAT_0051ada4 == 2) {
            surfaceDesc.ddpfPixelFormat.dwRBitMask = 0xf800;
            surfaceDesc.ddpfPixelFormat.dwGBitMask = 0x07e0;
            surfaceDesc.ddpfPixelFormat.dwBBitMask = 0x001f;
            surfaceDesc.ddpfPixelFormat.dwRGBAlphaBitMask = 0x0000;
        }
        surfaceDesc.dwFlags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PIXELFORMAT | DDSD_TEXTURESTAGE;
        surfaceDesc.ddsCaps.dwCaps = DDSCAPS_TEXTURE;
        surfaceDesc.ddsCaps.dwCaps2 = 0;
        surfaceDesc.dwWidth = widthMultipleOfMin;
        surfaceDesc.dwHeight = heightMultipleOfMin;

        if (IDirectDraw4_CreateSurface(gDirectDraw4, &surfaceDesc, &DAT_01b2ea60[texturePageIdx].surface, NULL) != DD_OK) {
            display_messagebox("could not create %s texture..", texPath);
        }
    }

    memset(&surfaceDesc2, 0, sizeof(DDSURFACEDESC2));
    surfaceDesc2.dwSize = sizeof(DDSURFACEDESC2);

    while (IDirectDrawSurface4_Lock(DAT_01b2ea60[texturePageIdx].surface, NULL, &surfaceDesc2, 0, NULL) != DD_OK) { }

    width2 = 256;
    height2 = 256;
    width3 = width;
    height3 = height;

    if (widthMultipleOfMin < width3) {
        width2 = (width3 << 8) / widthMultipleOfMin;
        width3 = widthMultipleOfMin;
    }

    if (heightMultipleOfMin < height3) {
        height2 = (height3 << 8) / heightMultipleOfMin;
        height3 = heightMultipleOfMin;
    }

    if (DAT_0051ada4 == 1) {
        uint16 *pDst;
        int32 y;

        memset(surfaceDesc2.lpSurface, 0, 
            heightMultipleOfMin * widthMultipleOfMin * sizeof(uint16));

        pDst = (uint16*)surfaceDesc2.lpSurface;

        for (y = 0; y < height3; y++) {
            uint16 *pCurrentDstWord;
            int32 x;

            pCurrentDstWord = pDst;

            for (x = 0; x < width3; x++) {
                *pCurrentDstWord = texBytes[((x * width2) >> 8) + ((y * height2) >> 8) * width];

                pCurrentDstWord++;
            }

            pDst += surfaceDesc2.lPitch / sizeof(uint16);
        }
    } else {
        uint16 *pDst;
        int32 y;
        
        memset(surfaceDesc2.lpSurface, 0, 
            heightMultipleOfMin * widthMultipleOfMin * sizeof(uint16));

        pDst = (uint16*)surfaceDesc2.lpSurface;

        for (y = 0; y < height3; y++) {
            uint16 *pCurrentDstWord;
            int32 x;

            pCurrentDstWord = pDst;

            for (x = 0; x < width3; x++) {
                *pCurrentDstWord = g16BitColorPallete[texBytes[((x * width2) >> 8) + ((y * height2) >> 8) * width]];

                pCurrentDstWord++;
            }

            pDst += surfaceDesc2.lPitch / sizeof(uint16);
        }
    }

    IDirectDrawSurface4_Unlock(DAT_01b2ea60[texturePageIdx].surface, NULL);

    if (textureId <= 0) {
        if (IDirectDrawSurface4_QueryInterface(DAT_01b2ea60[texturePageIdx].surface, 
                &IID_IDirect3DTexture2, &DAT_01b2ea60[texturePageIdx].texture) != DD_OK) {
            display_messagebox("Could not query texture surface");
        }

        colorKey.dwColorSpaceLowValue = 0;
        colorKey.dwColorSpaceHighValue = 0;

        if (IDirectDrawSurface4_SetColorKey(DAT_01b2ea60[texturePageIdx].surface, 8, &colorKey) != DD_OK) {
            display_messagebox("Couldn't set color key on texture..");
        }
    }

    return texturePageIdx + 1;
}

// Handles textures for cursors, fog of war edges, unit stars, and probably more
int FUN_00403720(uint16 *baseBytes, uint16 *alphaBytes, int32 width, int32 height, int32 textureId) {
    int32 widthMultipleOfMin;
    int32 heightMultipleOfMin;

    int32 texturePageIdx;

    DDSURFACEDESC2 surfaceDesc;
    DDSURFACEDESC2 surfaceDesc2;

    int32 width2;
    int32 width3;
    int32 height2;
    int32 height3;

    DDCOLORKEY colorKey;

    widthMultipleOfMin = ((gMinTextureWidth - 1 + width) / gMinTextureWidth) * gMinTextureWidth;
    heightMultipleOfMin = ((gMinTextureHeight - 1 + width) / gMinTextureHeight) * gMinTextureHeight;

    if (widthMultipleOfMin > gMaxTextureWidth) {
        widthMultipleOfMin = gMaxTextureWidth;
    }

    if (heightMultipleOfMin > gMaxTextureHeight) {
        heightMultipleOfMin = gMaxTextureHeight;
    }

    texturePageIdx = textureId - 1;
    if (texturePageIdx <= 0) {
        texturePageIdx = 0;

        while (texturePageIdx < 2048) {
            if (DAT_01b2ea60[texturePageIdx].texture == NULL && DAT_01b2ea60[texturePageIdx].unk0xc0 == NULL) {
                break;
            }

            texturePageIdx++;
        }

        if (texturePageIdx >= 2048) {
            display_messagebox("No more Texture pages available.");
        }

        DAT_01b2ea60[texturePageIdx].width = width;
        DAT_01b2ea60[texturePageIdx].height = height;
        DAT_01b2ea60[texturePageIdx].widthMultipleOfMin = widthMultipleOfMin;
        DAT_01b2ea60[texturePageIdx].heightMultipleOfMin = heightMultipleOfMin;
        DAT_01b2ea60[texturePageIdx].texBytes = alphaBytes;
        DAT_01b2ea60[texturePageIdx].unk0xbc = -1;
        DAT_01b2ea60[texturePageIdx].unk0xc0 = NULL;
        DAT_01b2ea60[texturePageIdx].unk0x28 = 1;
        DAT_01b2ea60[texturePageIdx].unk0x2c = 0;
        DAT_01b2ea60[texturePageIdx].unk0x30 = 0;
        DAT_01b2ea60[texturePageIdx].unk0x24 = 0;

        memset(&surfaceDesc, 0, sizeof(DDSURFACEDESC2));
        surfaceDesc.dwSize = sizeof(DDSURFACEDESC2);

        surfaceDesc.dwFlags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PIXELFORMAT;
        surfaceDesc.ddsCaps.dwCaps = DDSCAPS_TEXTURE;
        surfaceDesc.ddsCaps.dwCaps2 = 0;
        surfaceDesc.dwWidth = widthMultipleOfMin;
        surfaceDesc.dwHeight = heightMultipleOfMin;
        surfaceDesc.dwAlphaBitDepth = 4;
        surfaceDesc.ddpfPixelFormat.dwSize = sizeof(DDPIXELFORMAT);
        surfaceDesc.ddpfPixelFormat.dwRGBBitCount = 16;
        surfaceDesc.ddpfPixelFormat.dwFlags = DDPF_ALPHAPIXELS | DDPF_RGB;
        surfaceDesc.ddpfPixelFormat.dwRBitMask = 0x0f00;
        surfaceDesc.ddpfPixelFormat.dwGBitMask = 0x00f0;
        surfaceDesc.ddpfPixelFormat.dwBBitMask = 0x000f;
        surfaceDesc.ddpfPixelFormat.dwRGBAlphaBitMask = 0xf000;
        

        if (IDirectDraw4_CreateSurface(gDirectDraw4, &surfaceDesc, &DAT_01b2ea60[texturePageIdx].surface, NULL) != DD_OK) {
            display_messagebox("could not create alpha object texture..");
        }
    }

    memset(&surfaceDesc2, 0, sizeof(DDSURFACEDESC2));
    surfaceDesc2.dwSize = sizeof(DDSURFACEDESC2);

    while (IDirectDrawSurface4_Lock(DAT_01b2ea60[texturePageIdx].surface, NULL, &surfaceDesc2, 0, NULL) != DD_OK) { }

    width2 = 256;
    height2 = 256;
    width3 = width;
    height3 = height;

    if (widthMultipleOfMin < width3) {
        width2 = (width3 << 8) / widthMultipleOfMin;
        width3 = widthMultipleOfMin;
    }

    if (heightMultipleOfMin < height3) {
        height2 = (height3 << 8) / heightMultipleOfMin;
        height3 = heightMultipleOfMin;
    }

    {
        uint16 *pDst;
        int32 y;

        memset(surfaceDesc2.lpSurface, 0, 
            heightMultipleOfMin * widthMultipleOfMin * sizeof(uint16));

        pDst = (uint16*)surfaceDesc2.lpSurface;

        for (y = 0; y < height3; y++) {
            uint16 *pCurrentDstWord;
            int32 x;

            pCurrentDstWord = pDst;
            
            for (x = 0; x < width3; x++) {
                uint16 alphaWord = alphaBytes[((x * width2) >> 8) + ((y * height2) >> 8) * width];

                if (alphaWord != 0) {
                    uint16 alpha;
                    uint16 rgbWord;
                    uint16 rgb;

                    // Average alpha texture 5-bit RGB and pack it into the upper 4 bits of a word
                    alpha = (((alphaWord >> 10) & 0x1f) + ((alphaWord >> 5) & 0x1f) + ((alphaWord >> 0) & 0x1f)) / 3;
                    alpha = (alpha & 0xfffe) << 11;

                    if (alpha == 0) {
                        alpha = 0x1000;
                    }

                    // Convert 5-bit RGB to 4-bit RGB
                    rgbWord = baseBytes[((x * width2) >> 8) + ((y * height2) >> 8) * width];
                    rgb = ((rgbWord >> 3) & 0xf00) | ((rgbWord >> 2) & 0xf0) | ((rgbWord >> 1) & 0xf);

                    if (rgb == 0) {
                        rgb = 1;
                    }

                    // Combine alpha and RGB
                    *pCurrentDstWord = alpha | rgb;
                }

                pCurrentDstWord++;
            }

            pDst += surfaceDesc2.lPitch / sizeof(uint16);
        }
    }

    IDirectDrawSurface4_Unlock(DAT_01b2ea60[texturePageIdx].surface, NULL);

    if (textureId <= 0) {
        if (IDirectDrawSurface4_QueryInterface(DAT_01b2ea60[texturePageIdx].surface, 
                &IID_IDirect3DTexture2, &DAT_01b2ea60[texturePageIdx].texture) != DD_OK) {
            display_messagebox("Could not query texture surface");
        }

        colorKey.dwColorSpaceLowValue = 0;
        colorKey.dwColorSpaceHighValue = 0;

        if (IDirectDrawSurface4_SetColorKey(DAT_01b2ea60[texturePageIdx].surface, 8, &colorKey) != DD_OK) {
            display_messagebox("Couldn't set color key on texture..");
        }
    }

    return texturePageIdx + 1;
}

void try_init_zbuffer() {
    DDSURFACEDESC2 surfaceDesc;

    gZEnable = FALSE;

    IDirect3D3_EnumZBufferFormats(gDirect3D3, gD3DClassID, enum_zbuffer_formats_callback, &DAT_01b91140);

    if (!gZEnable) {
        return;
    }

    memset(&surfaceDesc, 0, sizeof(DDSURFACEDESC2));
    surfaceDesc.dwSize = sizeof(DDSURFACEDESC2);
    surfaceDesc.dwFlags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PIXELFORMAT;
    surfaceDesc.ddsCaps.dwCaps = DDSCAPS_VIDEOMEMORY | DDSCAPS_ZBUFFER;
    surfaceDesc.dwWidth = gDisplayWidth;
    surfaceDesc.dwHeight = gDisplayHeight;
    memcpy(&surfaceDesc.ddpfPixelFormat, &DAT_01b91140, sizeof(DDPIXELFORMAT));

    if (IDirectDraw4_CreateSurface(gDirectDraw4, &surfaceDesc, &gZBufferSurface, NULL) != DD_OK) {
        gZEnable = FALSE;
        return;
    }

    if (IDirectDrawSurface4_AddAttachedSurface(gDDBackBuffer, gZBufferSurface) != DD_OK) {
        IDirectDrawSurface4_Release(gZBufferSurface);
        gZEnable = FALSE;
    } else {
        if (DAT_0051ad80 != NULL) {
            custom_free(&DAT_0051ad80);
        }

        DAT_0051ad80 = custom_alloc(gDisplayHeight * gDisplayWidth * 2);
    }

    DAT_01b2dd80 = 0;
    DAT_01b2dd84 = 0;
    DAT_01b2dd88 = gDisplayWidth;
    DAT_01b2dd8c = gDisplayHeight;
}

HRESULT CALLBACK enum_zbuffer_formats_callback(LPDDPIXELFORMAT lpDDPixFmt, LPVOID lpContext) {
    if (lpDDPixFmt->dwFlags == DDPF_ZBUFFER && lpDDPixFmt->dwZBufferBitDepth == 16) {
        memcpy(lpContext, lpDDPixFmt, sizeof(DDPIXELFORMAT));
        gZEnable = TRUE;
    }

    return D3DENUMRET_OK;
}

void FUN_00403cf0(int32 textureId, int32 x, int32 y, int32 width, int32 height, int32 texLeft,
        int32 texTop, int32 texRight, int32 texBottom) {
    float32 widthMultipleOfMin;
    float32 heightMultipleOfMin;

    int32 triangleCount;

    float32 alpha;
    float32 r;
    float32 g;
    float32 b;

    float32 texLeft2;
    float32 texTop2;
    float32 texRight2;
    float32 texBottom2;

    D3DCOLOR color;
    D3DCOLOR specular;

    widthMultipleOfMin = DAT_01b2ea60[textureId - 1].widthMultipleOfMin - 1.0;
    heightMultipleOfMin = DAT_01b2ea60[textureId - 1].heightMultipleOfMin - 1.0;

    triangleCount = gVertexCount / 3;

    gTextureQueue[triangleCount] = textureId - 1;

    gViewportQueue[triangleCount].left = DAT_005f0b64;
    gViewportQueue[triangleCount].top = DAT_005f0b60;
    gViewportQueue[triangleCount].right = DAT_005f8c48;
    gViewportQueue[triangleCount].bottom = DAT_005f8c44;

    texLeft2 = texLeft / widthMultipleOfMin;
    texTop2 = texTop / heightMultipleOfMin;
    texRight2 = texRight / widthMultipleOfMin;
    texBottom2 = texBottom / heightMultipleOfMin;

    if (DAT_0051ada8 == 2) {
        alpha = 0.15f;
        gRenderFlagQueue[triangleCount] = 2;
    } else {
        alpha = 1.0f;
        gRenderFlagQueue[triangleCount] = 0;
    }

    gRenderFlagQueue[triangleCount] |= 0x10;

    gVertexQueue[gVertexCount + 0].sx = x;
    gVertexQueue[gVertexCount + 0].sy = y;
    gVertexQueue[gVertexCount + 0].sz = DAT_01b18068;
    gVertexQueue[gVertexCount + 0].rhw = 1.0f;
    gVertexQueue[gVertexCount + 1].sx = x;
    gVertexQueue[gVertexCount + 1].sy = y + height;
    gVertexQueue[gVertexCount + 1].sz = DAT_01b18068;
    gVertexQueue[gVertexCount + 1].rhw = 1.0f;
    gVertexQueue[gVertexCount + 2].sx = x + width;
    gVertexQueue[gVertexCount + 2].sy = y + height;
    gVertexQueue[gVertexCount + 2].sz = DAT_01b18068;
    gVertexQueue[gVertexCount + 2].rhw = 1.0f;

    gVertexQueue[gVertexCount + 0].tu = texLeft2;
    gVertexQueue[gVertexCount + 0].tv = texTop2;
    gVertexQueue[gVertexCount + 1].tu = texLeft2;
    gVertexQueue[gVertexCount + 1].tv = texBottom2;
    gVertexQueue[gVertexCount + 2].tu = texRight2;
    gVertexQueue[gVertexCount + 2].tv = texBottom2;

    r = 1.0f;
    g = 1.0f;
    b = 1.0f;

    if (DAT_0051ad84 != 0) {
        r = 0.4f;
        g = 0.6f;
        r = 0.9f;
    }

    color = D3DRGBA(r, g, b, alpha);
    specular = D3DRGBA(0, 0, 0, 0);

    gVertexQueue[gVertexCount + 0].color = color;
    gVertexQueue[gVertexCount + 0].specular = specular;
    gVertexQueue[gVertexCount + 1].color = color;
    gVertexQueue[gVertexCount + 1].specular = specular;
    gVertexQueue[gVertexCount + 2].color = color;
    gVertexQueue[gVertexCount + 2].specular = specular;

    gVertexCount += 3;

    triangleCount = gVertexCount / 3;

    gTextureQueue[triangleCount] = textureId - 1;

    gViewportQueue[triangleCount].left = DAT_005f0b64;
    gViewportQueue[triangleCount].top = DAT_005f0b60;
    gViewportQueue[triangleCount].right = DAT_005f8c48;
    gViewportQueue[triangleCount].bottom = DAT_005f8c44;

    if (DAT_0051ada8 == 2) {
        alpha = 0.15f;
        gRenderFlagQueue[triangleCount] = 2;
    } else {
        alpha = 1.0f;
        gRenderFlagQueue[triangleCount] = 0;
    }

    gRenderFlagQueue[triangleCount] |= 0x10;

    gVertexQueue[gVertexCount + 0].sx = x;
    gVertexQueue[gVertexCount + 0].sy = y;
    gVertexQueue[gVertexCount + 0].sz = DAT_01b18068;
    gVertexQueue[gVertexCount + 0].rhw = 1.0f;
    gVertexQueue[gVertexCount + 1].sx = x + width;
    gVertexQueue[gVertexCount + 1].sy = y + height;
    gVertexQueue[gVertexCount + 1].sz = DAT_01b18068;
    gVertexQueue[gVertexCount + 1].rhw = 1.0f;
    gVertexQueue[gVertexCount + 2].sx = x + width;
    gVertexQueue[gVertexCount + 2].sy = y;
    gVertexQueue[gVertexCount + 2].sz = DAT_01b18068;
    gVertexQueue[gVertexCount + 2].rhw = 1.0f;

    gVertexQueue[gVertexCount + 0].tu = texLeft2;
    gVertexQueue[gVertexCount + 0].tv = texTop2;
    gVertexQueue[gVertexCount + 1].tu = texRight2;
    gVertexQueue[gVertexCount + 1].tv = texBottom2;
    gVertexQueue[gVertexCount + 2].tu = texRight2;
    gVertexQueue[gVertexCount + 2].tv = texTop2;

    color = D3DRGBA(1.0f, 1.0f, 1.0f, alpha);
    specular = D3DRGBA(0, 0, 0, 0);

    gVertexQueue[gVertexCount + 0].color = color;
    gVertexQueue[gVertexCount + 0].specular = specular;
    gVertexQueue[gVertexCount + 1].color = color;
    gVertexQueue[gVertexCount + 1].specular = specular;
    gVertexQueue[gVertexCount + 2].color = color;
    gVertexQueue[gVertexCount + 2].specular = specular;

    DAT_0051ada8 = 0;

    gVertexCount += 3;
}

// Queues verts for fog of war edges
void FUN_00404380(int textureId, int x, int y, int width, int height, int matrixIdx) {
    int texWidth;
    int texHeight;

    int centerX;
    int centerY;

    int left;
    int top;
    int bottom;
    int right;

    float x_;
    float y_;
    float z_;

    int baseX;
    int baseY;

    int sxArray[6];
    int syArray[6];
    int tuArray[6];
    int tvArray[6];

    float widthMultipleOfMin;
    float heightMultipleOfMin;

    int i;

    Matrix3x3 matrix;

    texWidth = DAT_01b2ea60[textureId - 1].width;
    texHeight = DAT_01b2ea60[textureId - 1].height;

    centerX = x + width / 2;
    centerY = y + height / 2;

    top = y;
    left = x;
    bottom = y + height;
    right = x + width;

    FUN_00409aa0(&matrix, 2, matrixIdx);

    x_ = 0.0f;
    y_ = 0.0f;
    z_ = 0.0f; // <- not in original code
    mul_mat3_vec3(&matrix, &x_, &y_, &z_);
    baseX = centerX + x_;
    baseY = centerY + y_;

    x_ = centerX - right;
    y_ = centerY - top;
    z_ = 0.0f;
    mul_mat3_vec3(&matrix, &x_, &y_, &z_);
    sxArray[0] = baseX + x_;
    syArray[0] = baseY + y_;

    x_ = centerX - left;
    y_ = centerY - top;
    z_ = 0.0f;
    mul_mat3_vec3(&matrix, &x_, &y_, &z_);
    sxArray[1] = baseX + x_;
    syArray[1] = baseY + y_;

    x_ = centerX - left;
    y_ = centerY - bottom;
    z_ = 0.0f;
    mul_mat3_vec3(&matrix, &x_, &y_, &z_);
    sxArray[2] = baseX + x_;
    syArray[2] = baseY + y_;

    x_ = centerX - right;
    y_ = centerY - top;
    z_ = 0.0f;
    mul_mat3_vec3(&matrix, &x_, &y_, &z_);
    sxArray[3] = baseX + x_;
    syArray[3] = baseY + y_;

    x_ = centerX - left;
    y_ = centerY - bottom;
    z_ = 0.0f;
    mul_mat3_vec3(&matrix, &x_, &y_, &z_);
    sxArray[4] = baseX + x_;
    syArray[4] = baseY + y_;

    x_ = centerX - right;
    y_ = centerY - bottom;
    z_ = 0.0f;
    mul_mat3_vec3(&matrix, &x_, &y_, &z_);
    sxArray[5] = baseX + x_;
    syArray[5] = baseY + y_;

    tuArray[0] = texWidth - 1;
    tvArray[0] = 0;
    
    tuArray[1] = 0;
    tvArray[1] = 0;
    
    tuArray[2] = 0;
    tvArray[2] = texHeight - 1;
    
    tuArray[3] = texWidth - 1;
    tvArray[3] = 0;
    
    tuArray[4] = 0;
    tvArray[4] = texHeight - 1;

    tuArray[5] = texWidth - 1;
    tvArray[5] = texHeight - 1;

    if (((gVertexCount / 3) + 2) >= 16384) {
        return;
    }

    widthMultipleOfMin = DAT_01b2ea60[textureId - 1].widthMultipleOfMin - 1.0;
    heightMultipleOfMin = DAT_01b2ea60[textureId - 1].heightMultipleOfMin - 1.0;

    for (i = 0; i < 6; i += 3) {
        int32 triCount = gVertexCount / 3;

        gRenderFlagQueue[triCount] = 5;

        gTextureQueue[triCount] = textureId - 1;

        gViewportQueue[triCount].left = DAT_005f0b64;
        gViewportQueue[triCount].top = DAT_005f0b60;
        gViewportQueue[triCount].right = DAT_005f8c48;
        gViewportQueue[triCount].bottom = DAT_005f8c44;

        gVertexQueue[gVertexCount + 0].sx = sxArray[i + 0];
        gVertexQueue[gVertexCount + 0].sy = syArray[i + 0];
        gVertexQueue[gVertexCount + 0].sz = DAT_01b18068;
        gVertexQueue[gVertexCount + 0].rhw = 1.0f;

        gVertexQueue[gVertexCount + 1].sx = sxArray[i + 1];
        gVertexQueue[gVertexCount + 1].sy = syArray[i + 1];
        gVertexQueue[gVertexCount + 1].sz = DAT_01b18068;
        gVertexQueue[gVertexCount + 1].rhw = 1.0f;

        gVertexQueue[gVertexCount + 2].sx = sxArray[i + 2];
        gVertexQueue[gVertexCount + 2].sy = syArray[i + 2];
        gVertexQueue[gVertexCount + 2].sz = DAT_01b18068;
        gVertexQueue[gVertexCount + 2].rhw = 1.0f;

        gVertexQueue[gVertexCount + 0].tu = (tuArray[i + 0] + 0.5) / widthMultipleOfMin;
        gVertexQueue[gVertexCount + 0].tv = (tvArray[i + 0] + 0.5) / heightMultipleOfMin;

        gVertexQueue[gVertexCount + 1].tu = (tuArray[i + 1] + 0.5) / widthMultipleOfMin;
        gVertexQueue[gVertexCount + 1].tv = (tvArray[i + 1] + 0.5) / heightMultipleOfMin;

        gVertexQueue[gVertexCount + 2].tu = (tuArray[i + 2] + 0.5) / widthMultipleOfMin;
        gVertexQueue[gVertexCount + 2].tv = (tvArray[i + 2] + 0.5) / heightMultipleOfMin;

        gVertexQueue[gVertexCount + 0].color = D3DRGBA(1, 1, 1, 1);
        gVertexQueue[gVertexCount + 0].specular = D3DRGBA(0, 0, 0, 0);

        gVertexQueue[gVertexCount + 1].color = D3DRGBA(1, 1, 1, 1);
        gVertexQueue[gVertexCount + 1].specular = D3DRGBA(0, 0, 0, 0);

        gVertexQueue[gVertexCount + 2].color = D3DRGBA(1, 1, 1, 1);
        gVertexQueue[gVertexCount + 2].specular = D3DRGBA(0, 0, 0, 0);

        gVertexCount += 3;
    }
}
