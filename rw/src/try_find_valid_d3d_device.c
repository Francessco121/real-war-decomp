#include <ddraw.h>
#include <d3d.h>

int gSelectedD3DDevice;
int gD3DDeviceCounter;

void display_message(char *format, ...);
HRESULT WINAPI enum_devices_callback
    (LPGUID lpGUID,LPSTR lpszDeviceDesc,LPSTR lpszDeviceName,
    LPD3DDEVICEDESC lpd3dHWDeviceDesc,
    LPD3DDEVICEDESC lpd3dSWDeviceDesc,LPVOID lpUserArg);

// @ 0x00401150
int try_find_valid_d3d_device() {
    static LPDIRECT3D lpD3D;

    HRESULT result;
    LPDIRECTDRAW lpDD;

    result = DirectDrawCreate(NULL, &lpDD, NULL);

    if (result != S_OK) {
        display_message("Direct Draw 3D Object Failed");
        return 0;
    }

    result = IDirectDraw_QueryInterface(lpDD, &IID_IDirect3D, &lpD3D);
    
    if (result != S_OK) {
        display_message("Creation of Direct3D interface failed.");
        return 0;
    }

    gSelectedD3DDevice = -1;
    result = IDirect3D_EnumDevices(lpD3D, enum_devices_callback, &gSelectedD3DDevice);

    if (result != S_OK) {
        display_message("Enumeration of drivers failed.");
        return 0;
    }

    if (gD3DDeviceCounter == 0) {
        display_message("Could not find a D3D driver that is compatible with this program.");
        return 0;
    }

    IDirect3D_Release(lpD3D);
    lpD3D = NULL;

    return 1;
}
