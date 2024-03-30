add:
/* 0:  8b 44 24 04 */           mov        eax, dword ptr [esp + 4]
/* 4:  8b 4c 24 08 */           mov        ecx, dword ptr [esp + 8]
/* 8:  01 08 */                 add        dword ptr [eax], ecx
/* a:  c3 */                    ret        


do_thing:
/* 10:  51 */                   push       ecx
/* 11:  56 */                   push       esi
/* 12:  57 */                   push       edi
/* 13:  8b 7c 24 10 */          mov        edi, dword ptr [esp + 0x10]
/* 17:  33 c0 */                xor        eax, eax
/* 19:  33 f6 */                xor        esi, esi
/* 1b:  89 44 24 08 */          mov        dword ptr [esp + 8], eax
/* 1f:  85 ff */                test       edi, edi
/* 21:  7e 17 */                jle        _L3a
_L23:
/* 23:  8d 44 24 08 */          lea        eax, [esp + 8]
/* 27:  56 */                   push       esi
/* 28:  50 */                   push       eax
/* 29:  e8 d2 ff ff 00 */       call       add
/* 2e:  83 c4 08 */             add        esp, 8
/* 31:  46 */                   inc        esi
/* 32:  3b f7 */                cmp        esi, edi
/* 34:  7c ed */                jl         _L23
/* 36:  8b 44 24 08 */          mov        eax, dword ptr [esp + 8]
_L3a:
/* 3a:  5f */                   pop        edi
/* 3b:  5e */                   pop        esi
/* 3c:  59 */                   pop        ecx
/* 3d:  c3 */                   ret        


do_thing_inline:
/* 40:  8b 54 24 04 */          mov        edx, dword ptr [esp + 4]
/* 44:  33 c0 */                xor        eax, eax
/* 46:  33 c9 */                xor        ecx, ecx
/* 48:  85 d2 */                test       edx, edx
/* 4a:  7e 07 */                jle        _L53
_L4c:
/* 4c:  03 c1 */                add        eax, ecx
/* 4e:  41 */                   inc        ecx
/* 4f:  3b ca */                cmp        ecx, edx
/* 51:  7c f9 */                jl         _L4c
_L53:
/* 53:  c3 */                   ret        


check:
/* 60:  51 */                   push       ecx
/* 61:  e8 9a ff ff 02 */       call       get2
/* 66:  89 44 24 00 */          mov        dword ptr [esp], eax
/* 6a:  8d 44 24 00 */          lea        eax, [esp]
/* 6e:  50 */                   push       eax
/* 6f:  e8 90 ff ff 02 */       call       bar
/* 74:  8b 4c 24 0c */          mov        ecx, dword ptr [esp + 0xc]
/* 78:  33 c0 */                xor        eax, eax
/* 7a:  8b 11 */                mov        edx, dword ptr [ecx]
/* 7c:  8b 4c 24 04 */          mov        ecx, dword ptr [esp + 4]
/* 80:  3b d1 */                cmp        edx, ecx
/* 82:  0f 94 c0 */             sete       al
/* 85:  83 c4 08 */             add        esp, 8
/* 88:  c3 */                   ret        


short_circuit:
/* 90:  51 */                   push       ecx
/* 91:  e8 72 ff ff 02 */       call       get
/* 96:  89 44 24 00 */          mov        dword ptr [esp], eax
/* 9a:  8d 44 24 00 */          lea        eax, [esp]
/* 9e:  50 */                   push       eax
/* 9f:  e8 60 ff ff 00 */       call       check
/* a4:  83 c4 04 */             add        esp, 4
/* a7:  85 c0 */                test       eax, eax
/* a9:  75 05 */                jne        _Lb0
/* ab:  e8 5c ff ff 02 */       call       foo
_Lb0:
/* b0:  59 */                   pop        ecx
/* b1:  c3 */                   ret        


short_circuit_inline:
/* c0:  51 */                   push       ecx
/* c1:  56 */                   push       esi
/* c2:  e8 41 ff ff 02 */       call       get
/* c7:  8b f0 */                mov        esi, eax
/* c9:  e8 32 ff ff 02 */       call       get2
/* ce:  89 44 24 04 */          mov        dword ptr [esp + 4], eax
/* d2:  8d 44 24 04 */          lea        eax, [esp + 4]
/* d6:  50 */                   push       eax
/* d7:  e8 28 ff ff 02 */       call       bar
/* dc:  8b 44 24 08 */          mov        eax, dword ptr [esp + 8]
/* e0:  83 c4 04 */             add        esp, 4
/* e3:  3b f0 */                cmp        esi, eax
/* e5:  5e */                   pop        esi
/* e6:  74 05 */                je         _Led
/* e8:  e8 1f ff ff 02 */       call       foo
_Led:
/* ed:  59 */                   pop        ecx
/* ee:  c3 */                   ret        


# RELOCATED SYMBOL MAPPING:
# add = 0x1000000
# check = 0x1000004
# get2 = 0x3000000
# bar = 0x3000004
# get = 0x3000008
# foo = 0x300000c
