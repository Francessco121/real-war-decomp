# Optimizer Notes
Notes on how the MSVC 98 C compiler emits optimized code and patterns that can be potentially spotted.


## Globals in a struct vs ungrouped
```c
// i.e.
int a;
int b;
// versus
struct _s {
    int a;
    int b;
} s;
```

Code using a variable from a global struct multiple times in succession does not seem to reuse the value of the variable and will re-read the global each time it's needed. **Note: The presence of a struct does not always lead to the value not being reused. In simpler scenarios, the value of the global can still be reused.** In larger/more complex functions, this *can* cause big differences in regalloc and instruction ordering.
```
# With global struct                         # Without global struct
mov  ecx, dword ptr [s.counter]          o   mov  eax, dword ptr [counter]
mov  edx, dword ptr [esp + 0x14]         o   mov  edx, dword ptr [esp + 0x10]
shl  ecx, 4                              |   mov  ecx, eax
                                         >   push ebp
mov  eax, dword ptr [edx]                o   mov  ebp, dword ptr [edx]
                                         >   lea  eax, [eax + eax*4]
                                         >   shl  ecx, 4
add  ecx, s.guids                            add  ecx, guids
                                         >   lea  eax, [eax + eax*4]
push ebx                                     push ebx
mov  ebx, dword ptr [lstrcpyA]               mov  ebx, dword ptr [lstrcpyA]
mov  dword ptr [ecx], eax                o   mov  dword ptr [ecx], ebp
mov  eax, dword ptr [edx + 4]            o   mov  ebp, dword ptr [edx + 4]
mov  dword ptr [ecx + 4], eax            o   mov  dword ptr [ecx + 4], ebp
mov  eax, dword ptr [edx + 8]            o   mov  ebp, dword ptr [edx + 8]
mov  dword ptr [ecx + 8], eax            o   mov  dword ptr [ecx + 8], ebp
mov  edx, dword ptr [edx + 0xc]              mov  edx, dword ptr [edx + 0xc]
mov  dword ptr [ecx + 0xc], edx              mov  dword ptr [ecx + 0xc], edx
# Notably this load is optimized out when *not* using a global struct
# Most of the other changes are just regalloc and the same code but moved around
mov  eax, dword ptr [s.counter]          <
lea  eax, [eax + eax*4]                  o   lea  ecx, [eax*2 + devNames]
lea  eax, [eax + eax*4]                  <
lea  ecx, [eax*2 + s.devNames]           <
```
