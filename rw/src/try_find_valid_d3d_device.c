#include <ddraw.h>
#include <d3d.h>

#include "strings.h"
#include "undefined.h"

// .bss

int gSelectedD3DDevice;
int gD3DDeviceCounter;

// .text

extern HRESULT WINAPI enum_devices_callback
    (LPGUID lpGUID,LPSTR lpszDeviceDesc,LPSTR lpszDeviceName,
    LPD3DDEVICEDESC lpd3dHWDeviceDesc,
    LPD3DDEVICEDESC lpd3dSWDeviceDesc,LPVOID lpUserArg);

int try_find_valid_d3d_device() {
    static LPDIRECT3D lpD3D;

    HRESULT result;
    LPDIRECTDRAW lpDD;

    result = DirectDrawCreate(NULL, &lpDD, NULL);

    if (result != S_OK) {
        display_message(str_dd3d_obj_failed);
        return 0;
    }

    result = IDirectDraw_QueryInterface(lpDD, &IID_IDirect3D, &lpD3D);
    
    if (result != S_OK) {
        display_message(str_creation_of_id3d_failed);
        return 0;
    }

    gSelectedD3DDevice = -1;
    result = IDirect3D_EnumDevices(lpD3D, enum_devices_callback, &gSelectedD3DDevice);

    if (result != S_OK) {
        display_message(str_enum_of_drivers_failed);
        return 0;
    }

    if (gD3DDeviceCounter == 0) {
        display_message(str_couldnt_find_compatible_d3d_driver);
        return 0;
    }

    IDirect3D_Release(lpD3D);
    lpD3D = NULL;

    return 1;
}
