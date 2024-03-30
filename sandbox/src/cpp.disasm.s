?test:
/* 0:  8b 44 24 08 */           mov        eax, dword ptr [esp + 8]
/* 4:  8b 4c 24 04 */           mov        ecx, dword ptr [esp + 4]
/* 8:  03 c1 */                 add        eax, ecx
/* a:  c2 08 00 */              ret        8


?get:
/* 10:  8b 01 */                mov        eax, dword ptr [ecx]
/* 12:  c3 */                   ret        


?biggerTest:
/* 20:  8b 4c 24 08 */          mov        ecx, dword ptr [esp + 8]
/* 24:  8b 54 24 04 */          mov        edx, dword ptr [esp + 4]
/* 28:  8b 44 24 0c */          mov        eax, dword ptr [esp + 0xc]
/* 2c:  56 */                   push       esi
/* 2d:  2b d1 */                sub        edx, ecx
/* 2f:  be 0a 00 00 00 */       mov        esi, 0xa
_L34:
/* 34:  89 04 0a */             mov        dword ptr [edx + ecx], eax
/* 37:  89 01 */                mov        dword ptr [ecx], eax
/* 39:  83 c1 04 */             add        ecx, 4
/* 3c:  4e */                   dec        esi
/* 3d:  75 f5 */                jne        _L34
/* 3f:  5e */                   pop        esi
/* 40:  c2 0c 00 */             ret        0xc


# RELOCATED SYMBOL MAPPING:
