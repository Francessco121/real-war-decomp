single:
/* 0:  a1 00 00 00 03 */        mov        eax, dword ptr [s2]
/* 5:  8b 0c 85 04 00 00 03 */  mov        ecx, dword ptr [eax*4 + array2]
/* c:  8b 14 85 08 00 00 03 */  mov        edx, dword ptr [eax*4 + array4]
/* 13:  89 0c 85 0c 00 00 03 */ mov        dword ptr [eax*4 + array1], ecx
/* 1a:  89 14 85 10 00 00 03 */ mov        dword ptr [eax*4 + array3], edx
/* 21:  c3 */                   ret        


grouped:
/* 30:  8b 44 24 04 */          mov        eax, dword ptr [esp + 4]
/* 34:  56 */                   push       esi
/* 35:  57 */                   push       edi
/* 36:  8b 7c 24 10 */          mov        edi, dword ptr [esp + 0x10]
/* 3a:  8b 08 */                mov        ecx, dword ptr [eax]
/* 3c:  89 0d 14 00 00 03 */    mov        dword ptr [s], ecx
/* 42:  8b 50 04 */             mov        edx, dword ptr [eax + 4]
/* 45:  89 15 18 00 00 03 */    mov        dword ptr [s + 0x4], edx
/* 4b:  8b 48 08 */             mov        ecx, dword ptr [eax + 8]
/* 4e:  89 0d 1c 00 00 03 */    mov        dword ptr [s + 0x8], ecx
/* 54:  83 c9 ff */             or         ecx, 0xffffffff
/* 57:  8b 50 0c */             mov        edx, dword ptr [eax + 0xc]
/* 5a:  a1 a8 0c 00 03 */       mov        eax, dword ptr [s + 0xc94]
/* 5f:  89 15 20 00 00 03 */    mov        dword ptr [s + 0xc], edx
/* 65:  8d 04 80 */             lea        eax, [eax + eax*4]
/* 68:  8d 04 80 */             lea        eax, [eax + eax*4]
/* 6b:  8d 14 45 b4 00 00 03 */ lea        edx, [eax*2 + s + 0xa0]
/* 72:  33 c0 */                xor        eax, eax
/* 74:  f2 ae */                repne scasb al, byte ptr es:[edi]
/* 76:  f7 d1 */                not        ecx
/* 78:  2b f9 */                sub        edi, ecx
/* 7a:  8b c1 */                mov        eax, ecx
/* 7c:  8b f7 */                mov        esi, edi
/* 7e:  8b fa */                mov        edi, edx
/* 80:  c1 e9 02 */             shr        ecx, 2
/* 83:  f3 a5 */                rep movsd  dword ptr es:[edi], dword ptr [esi]
/* 85:  8b c8 */                mov        ecx, eax
/* 87:  33 c0 */                xor        eax, eax
/* 89:  83 e1 03 */             and        ecx, 3
/* 8c:  f3 a4 */                rep movsb  byte ptr es:[edi], byte ptr [esi]
/* 8e:  8b 15 a8 0c 00 03 */    mov        edx, dword ptr [s + 0xc94]
/* 94:  8b 7c 24 14 */          mov        edi, dword ptr [esp + 0x14]
/* 98:  c1 e2 08 */             shl        edx, 8
/* 9b:  83 c9 ff */             or         ecx, 0xffffffff
/* 9e:  81 c2 a8 02 00 03 */    add        edx, s + 0x294
/* a4:  f2 ae */                repne scasb al, byte ptr es:[edi]
/* a6:  f7 d1 */                not        ecx
/* a8:  2b f9 */                sub        edi, ecx
/* aa:  8b c1 */                mov        eax, ecx
/* ac:  8b f7 */                mov        esi, edi
/* ae:  8b fa */                mov        edi, edx
/* b0:  c1 e9 02 */             shr        ecx, 2
/* b3:  f3 a5 */                rep movsd  dword ptr es:[edi], dword ptr [esi]
/* b5:  8b c8 */                mov        ecx, eax
/* b7:  83 e1 03 */             and        ecx, 3
/* ba:  f3 a4 */                rep movsb  byte ptr es:[edi], byte ptr [esi]
/* bc:  a1 a8 0c 00 03 */       mov        eax, dword ptr [s + 0xc94]
/* c1:  5f */                   pop        edi
/* c2:  40 */                   inc        eax
/* c3:  5e */                   pop        esi
/* c4:  a3 a8 0c 00 03 */       mov        dword ptr [s + 0xc94], eax
/* c9:  c3 */                   ret        


# RELOCATED SYMBOL MAPPING:
# s2 = 0x3000000
# array2 = 0x3000004
# array4 = 0x3000008
# array1 = 0x300000c
# array3 = 0x3000010
# s = 0x3000014
