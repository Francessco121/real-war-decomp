#include <DDRAW.h>
#include <D3D.h>

#include "strings.h"
#include "types.h"
#include "undefined.h"
#include "window.h"

// .bss

int32 gSelectedD3DDevice;
int32 gD3DDeviceCounter;

// .text

extern HRESULT WINAPI enum_devices_callback
    (LPGUID lpGUID,LPSTR lpszDeviceDesc,LPSTR lpszDeviceName,
    LPD3DDEVICEDESC lpd3dHWDeviceDesc,
    LPD3DDEVICEDESC lpd3dSWDeviceDesc,LPVOID lpUserArg);

bool try_find_valid_d3d_device() {
    static LPDIRECT3D lpD3D;

    HRESULT result;
    LPDIRECTDRAW lpDD;

    result = DirectDrawCreate(NULL, &lpDD, NULL);

    if (result != S_OK) {
        display_messagebox(str_dd3d_obj_failed);
        return FALSE;
    }

    result = IDirectDraw_QueryInterface(lpDD, &IID_IDirect3D, &lpD3D);
    
    if (result != S_OK) {
        display_messagebox(str_creation_of_id3d_failed);
        return FALSE;
    }

    gSelectedD3DDevice = -1;
    result = IDirect3D_EnumDevices(lpD3D, enum_devices_callback, &gSelectedD3DDevice);

    if (result != S_OK) {
        display_messagebox(str_enum_of_drivers_failed);
        return FALSE;
    }

    if (gD3DDeviceCounter == 0) {
        display_messagebox(str_couldnt_find_compatible_d3d_driver);
        return FALSE;
    }

    IDirect3D_Release(lpD3D);
    lpD3D = NULL;

    return TRUE;
}
