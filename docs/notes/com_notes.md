COM interfaces are defined as structs with the first field always being a virtual method table.

DECLARE_INTERFACE_ macro expansion example:
```c
typedef struct IDirect3D {
    struct IDirect3DVtbl *lpVtbl;
} IDirect3D;

typedef const struct IDirect3DVtbl IDirect3DVtbl;

const struct IDirect3DVtbl {
    /*** IUnknown methods ***/
    HRESULT (__stdcall * QueryInterface)(IDirect3D * This, const IID * const riid, LPVOID * ppvObj);
    ULONG (__stdcall * AddRef)(IDirect3D * This);
    ULONG (__stdcall * Release)(IDirect3D * This);
    
    /*** IDirect3D methods ***/
    HRESULT (__stdcall * Initialize)(IDirect3D * This, const IID * const);
    HRESULT (__stdcall * EnumDevices)(IDirect3D * This, LPD3DENUMDEVICESCALLBACK, LPVOID);
    HRESULT (__stdcall * CreateLight)(IDirect3D * This, LPDIRECT3DLIGHT*, IUnknown*);
    HRESULT (__stdcall * CreateMaterial)(IDirect3D * This, LPDIRECT3DMATERIAL*, IUnknown*);
    HRESULT (__stdcall * CreateViewport)(IDirect3D * This, LPDIRECT3DVIEWPORT*, IUnknown*);
    HRESULT (__stdcall * FindDevice)(IDirect3D * This, LPD3DFINDDEVICESEARCH, LPD3DFINDDEVICERESULT);
};
```

COM interfaces usually also declare a pointer typedef:
```c
typedef struct IDirect3D *LPDIRECT3D;
```

For C programming, there's also usually macros defined for each function:
```c
// i.e. instead of
lpD3D->lpVtbl->Release(lpD3D);
// you can do
IDirect3D_Release(lpD3D);
```
