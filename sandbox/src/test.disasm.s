do_thing:
/* 0:  81 ec 00 08 00 00 */     sub        esp, 0x800
/* 6:  b9 00 08 00 00 */        mov        ecx, 0x800
/* b:  33 c0 */                 xor        eax, eax
/* d:  8d 54 24 00 */           lea        edx, [esp]
/* 11:  56 */                   push       esi
/* 12:  57 */                   push       edi
/* 13:  8d 7c 24 08 */          lea        edi, [esp + 8]
/* 17:  f3 ab */                rep stosd  dword ptr es:[edi], eax
/* 19:  8b bc 24 0c 08 00 00 */ mov        edi, dword ptr [esp + 0x80c]
/* 20:  8d 44 24 08 */          lea        eax, [esp + 8]
/* 24:  8b cf */                mov        ecx, edi
/* 26:  2b ca */                sub        ecx, edx
/* 28:  ba 00 08 00 00 */       mov        edx, 0x800
_L2d:
/* 2d:  8b 34 01 */             mov        esi, dword ptr [ecx + eax]
/* 30:  83 c0 04 */             add        eax, 4
/* 33:  46 */                   inc        esi
/* 34:  4a */                   dec        edx
/* 35:  89 70 fc */             mov        dword ptr [eax - 4], esi
/* 38:  75 f3 */                jne        _L2d
/* 3a:  b9 00 02 00 00 */       mov        ecx, 0x200
/* 3f:  8d 74 24 08 */          lea        esi, [esp + 8]
/* 43:  f3 a5 */                rep movsd  dword ptr es:[edi], dword ptr [esi]
/* 45:  5f */                   pop        edi
/* 46:  5e */                   pop        esi
/* 47:  81 c4 00 08 00 00 */    add        esp, 0x800
/* 4d:  c3 */                   ret        


main:
/* 50:  81 ec 00 08 00 00 */    sub        esp, 0x800
/* 56:  b9 00 08 00 00 */       mov        ecx, 0x800
/* 5b:  33 c0 */                xor        eax, eax
/* 5d:  57 */                   push       edi
/* 5e:  8d 7c 24 04 */          lea        edi, [esp + 4]
/* 62:  f3 ab */                rep stosd  dword ptr es:[edi], eax
/* 64:  8d 44 24 04 */          lea        eax, [esp + 4]
/* 68:  50 */                   push       eax
/* 69:  e8 92 ff ff 00 */       call       do_thing
/* 6e:  83 c4 04 */             add        esp, 4
/* 71:  5f */                   pop        edi
/* 72:  81 c4 00 08 00 00 */    add        esp, 0x800
/* 78:  c3 */                   ret        


# RELOCATED SYMBOL MAPPING:
# do_thing = 0x1000000

# cl_wrapper stdout:
# src\test.c(23) : warning C4101: 'i' : unreferenced local variable
