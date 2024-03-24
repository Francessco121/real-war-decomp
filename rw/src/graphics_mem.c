#include <STRING.H>

#include "types.h"
#include "undefined.h"
#include "window_graphics.h"

void memcpy_dword(uint32 *dst, uint32 *src, size_t count) {
    // equiv: memcpy(dst, src, count * 4);

    __asm {
        push ecx
        push edi
        push esi
        mov edi, dword ptr [dst]
        mov esi, dword ptr [src]
        mov ecx, dword ptr [count]
        rep movsd
        pop esi
        pop edi
        pop ecx
    }
}

void memset_dword(uint32 *dst, uint32 value, size_t count) {
    // equiv:
    // size_t i;
    // for (i = 0; i < count; i++) {
    //     dst[i] = value;
    // }
    
    __asm {
        push ecx
        push edi
        mov edi, dword ptr [dst]
        mov eax, dword ptr [value]
        mov ecx, dword ptr [count]
        rep stosd
        pop edi
        pop ecx
    }
}

void memset_word(uint16 *dst, uint16 value, size_t count) {
    // equiv:
    // size_t i;
    // for (i = 0; i < count; i++) {
    //     dst[i] = value;
    // }

    __asm {
        push ecx
        push edi
        mov edi, dword ptr [dst]
        mov ax, word ptr [value]
        mov ecx, dword ptr [count]
        rep stosw
        pop edi
        pop ecx
    }
}

// This needs some work
// Seems to be called primarily for generating screenshots
#ifdef NON_EQUIVALENT
void copy_frontbuffer(uint16 *out) {
    int32 prevValue;
    DDSURFACEDESC surfaceDesc;
    int32 x;
    int32 y;
    uint16 pixel;

    prevValue = DAT_0051b90c;

    if (gD3DDeviceFound != 0) {
        surfaceDesc.dwSize = sizeof(DDSURFACEDESC);

        // BUG: surfaceDesc should be a DDSURFACEDESC2 here
        while ((DAT_00567aa0 = IDirectDrawSurface4_Lock(gDDFrontBuffer, NULL, &surfaceDesc, 0, NULL)) != DD_OK) { }
        DAT_00567aa0 = DD_OK;

        for (y = 0; y < gDisplayHeight; y++) {
            if (DAT_0051b960 != 0) {
                for (x = 0; x < gDisplayWidth; x++) {
                    out[x] = ((uint16*)surfaceDesc.lpSurface)[((surfaceDesc.lPitch >> 1) * y) + x];
                }
            } else {
                for (x = 0; x < gDisplayWidth; x++) {
                    pixel = ((uint16*)surfaceDesc.lpSurface)[((surfaceDesc.lPitch >> 1) * y) + x];
                    out[x] = ((pixel >> 1) & 0x7fe0) | (pixel & 0x1f);
                }
            }
        }

        IDirectDrawSurface4_Unlock(gDDFrontBuffer, NULL);
    } else {
        for (y = 0; y < gDisplayHeight; y++) {
            for (x = 0; x < gDisplayWidth; x++) {
                out[x] = gInMemoryGraphicsSurface[(gDisplayWidth * y) + x];
            }
        }
    }

    DAT_0051b90c = prevValue;
}
#else
#pragma ASM_FUNC copy_frontbuffer
#endif
