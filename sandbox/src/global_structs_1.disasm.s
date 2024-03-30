single:
/* 0:  a1 00 00 00 03 */        mov        eax, dword ptr [value]
/* 5:  8b 0c 85 04 00 00 03 */  mov        ecx, dword ptr [eax*4 + array2]
/* c:  8b 14 85 08 00 00 03 */  mov        edx, dword ptr [eax*4 + array4]
/* 13:  89 0c 85 0c 00 00 03 */ mov        dword ptr [eax*4 + array1], ecx
/* 1a:  89 14 85 10 00 00 03 */ mov        dword ptr [eax*4 + array3], edx
/* 21:  c3 */                   ret        


ungrouped:
/* 30:  8b 44 24 04 */          mov        eax, dword ptr [esp + 4]
/* 34:  53 */                   push       ebx
/* 35:  56 */                   push       esi
/* 36:  57 */                   push       edi
/* 37:  8b 08 */                mov        ecx, dword ptr [eax]
/* 39:  8b 7c 24 14 */          mov        edi, dword ptr [esp + 0x14]
/* 3d:  89 0d 14 00 00 03 */    mov        dword ptr [guids], ecx
/* 43:  8b 50 04 */             mov        edx, dword ptr [eax + 4]
/* 46:  89 15 18 00 00 03 */    mov        dword ptr [guids + 0x4], edx
/* 4c:  8b 48 08 */             mov        ecx, dword ptr [eax + 8]
/* 4f:  89 0d 1c 00 00 03 */    mov        dword ptr [guids + 0x8], ecx
/* 55:  83 c9 ff */             or         ecx, 0xffffffff
/* 58:  8b 50 0c */             mov        edx, dword ptr [eax + 0xc]
/* 5b:  89 15 20 00 00 03 */    mov        dword ptr [guids + 0xc], edx
/* 61:  8b 15 00 00 00 02 */    mov        edx, dword ptr [counter]
/* 67:  8d 04 92 */             lea        eax, [edx + edx*4]
/* 6a:  8d 04 80 */             lea        eax, [eax + eax*4]
/* 6d:  8d 1c 45 b4 00 00 03 */ lea        ebx, [eax*2 + names]
/* 74:  33 c0 */                xor        eax, eax
/* 76:  f2 ae */                repne scasb al, byte ptr es:[edi]
/* 78:  f7 d1 */                not        ecx
/* 7a:  2b f9 */                sub        edi, ecx
/* 7c:  8b c1 */                mov        eax, ecx
/* 7e:  8b f7 */                mov        esi, edi
/* 80:  8b fb */                mov        edi, ebx
/* 82:  8b da */                mov        ebx, edx
/* 84:  c1 e9 02 */             shr        ecx, 2
/* 87:  f3 a5 */                rep movsd  dword ptr es:[edi], dword ptr [esi]
/* 89:  8b c8 */                mov        ecx, eax
/* 8b:  33 c0 */                xor        eax, eax
/* 8d:  83 e1 03 */             and        ecx, 3
/* 90:  f3 a4 */                rep movsb  byte ptr es:[edi], byte ptr [esi]
/* 92:  8b 7c 24 18 */          mov        edi, dword ptr [esp + 0x18]
/* 96:  83 c9 ff */             or         ecx, 0xffffffff
/* 99:  c1 e3 08 */             shl        ebx, 8
/* 9c:  81 c3 a8 02 00 03 */    add        ebx, descriptions
/* a2:  f2 ae */                repne scasb al, byte ptr es:[edi]
/* a4:  f7 d1 */                not        ecx
/* a6:  2b f9 */                sub        edi, ecx
/* a8:  8b c1 */                mov        eax, ecx
/* aa:  8b f7 */                mov        esi, edi
/* ac:  8b fb */                mov        edi, ebx
/* ae:  c1 e9 02 */             shr        ecx, 2
/* b1:  f3 a5 */                rep movsd  dword ptr es:[edi], dword ptr [esi]
/* b3:  8b c8 */                mov        ecx, eax
/* b5:  83 e1 03 */             and        ecx, 3
/* b8:  42 */                   inc        edx
/* b9:  f3 a4 */                rep movsb  byte ptr es:[edi], byte ptr [esi]
/* bb:  5f */                   pop        edi
/* bc:  5e */                   pop        esi
/* bd:  89 15 00 00 00 02 */    mov        dword ptr [counter], edx
/* c3:  5b */                   pop        ebx
/* c4:  c3 */                   ret        


# RELOCATED SYMBOL MAPPING:
# counter = 0x2000000
# value = 0x3000000
# array2 = 0x3000004
# array4 = 0x3000008
# array1 = 0x300000c
# array3 = 0x3000010
# guids = 0x3000014
# names = 0x30000b4
# descriptions = 0x30002a8
