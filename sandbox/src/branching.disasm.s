example1:
/* 0:  a1 00 00 00 03 */        mov        eax, dword ptr [a]
/* 5:  85 c0 */                 test       eax, eax
/* 7:  74 05 */                 je         _Le
/* 9:  e9 f6 ff ff 02 */        jmp        branch1
_Le:
/* e:  a1 08 00 00 03 */        mov        eax, dword ptr [b]
/* 13:  85 c0 */                test       eax, eax
/* 15:  74 05 */                je         _L1c
/* 17:  e9 f0 ff ff 02 */       jmp        branch2
_L1c:
/* 1c:  a1 10 00 00 03 */       mov        eax, dword ptr [c]
/* 21:  85 c0 */                test       eax, eax
/* 23:  74 05 */                je         _L2a
/* 25:  e9 ea ff ff 02 */       jmp        branch3
_L2a:
/* 2a:  e9 e9 ff ff 02 */       jmp        branch4


example2:
/* 30:  a1 00 00 00 03 */       mov        eax, dword ptr [a]
/* 35:  85 c0 */                test       eax, eax
/* 37:  75 0e */                jne        _L47
/* 39:  a1 08 00 00 03 */       mov        eax, dword ptr [b]
/* 3e:  85 c0 */                test       eax, eax
/* 40:  75 05 */                jne        _L47
/* 42:  e9 c5 ff ff 02 */       jmp        branch2
_L47:
/* 47:  e9 b8 ff ff 02 */       jmp        branch1


example3:
/* 50:  a1 00 00 00 03 */       mov        eax, dword ptr [a]
/* 55:  85 c0 */                test       eax, eax
/* 57:  75 1c */                jne        _L75
/* 59:  a1 08 00 00 03 */       mov        eax, dword ptr [b]
/* 5e:  85 c0 */                test       eax, eax
/* 60:  75 13 */                jne        _L75
/* 62:  a1 10 00 00 03 */       mov        eax, dword ptr [c]
/* 67:  85 c0 */                test       eax, eax
/* 69:  74 05 */                je         _L70
/* 6b:  e9 9c ff ff 02 */       jmp        branch2
_L70:
/* 70:  e9 9f ff ff 02 */       jmp        branch3
_L75:
/* 75:  e9 8a ff ff 02 */       jmp        branch1


example4:
/* 80:  a1 00 00 00 03 */       mov        eax, dword ptr [a]
/* 85:  85 c0 */                test       eax, eax
/* 87:  74 0e */                je         _L97
/* 89:  a1 08 00 00 03 */       mov        eax, dword ptr [b]
/* 8e:  85 c0 */                test       eax, eax
/* 90:  74 05 */                je         _L97
/* 92:  e9 6d ff ff 02 */       jmp        branch1
_L97:
/* 97:  a1 10 00 00 03 */       mov        eax, dword ptr [c]
/* 9c:  85 c0 */                test       eax, eax
/* 9e:  74 05 */                je         _La5
/* a0:  e9 67 ff ff 02 */       jmp        branch2
_La5:
/* a5:  e9 6a ff ff 02 */       jmp        branch3


example5:
/* b0:  a1 00 00 00 03 */       mov        eax, dword ptr [a]
/* b5:  83 f8 04 */             cmp        eax, 4
/* b8:  75 10 */                jne        _Lca
/* ba:  83 3d 08 00 00 03 04 */ cmp        dword ptr [b], 4
/* c1:  74 1c */                je         _Ldf
/* c3:  e8 3c ff ff 02 */       call       branch1
/* c8:  eb 1a */                jmp        _Le4
_Lca:
/* ca:  83 f8 02 */             cmp        eax, 2
/* cd:  75 10 */                jne        _Ldf
/* cf:  83 3d 08 00 00 03 02 */ cmp        dword ptr [b], 2
/* d6:  74 07 */                je         _Ldf
/* d8:  e8 2f ff ff 02 */       call       branch2
/* dd:  eb 05 */                jmp        _Le4
_Ldf:
/* df:  e8 30 ff ff 02 */       call       branch3
_Le4:
/* e4:  e9 33 ff ff 02 */       jmp        end


example6:
/* f0:  a1 00 00 00 03 */       mov        eax, dword ptr [a]
/* f5:  8b 0d 08 00 00 03 */    mov        ecx, dword ptr [b]
/* fb:  8b 04 85 20 00 00 03 */ mov        eax, dword ptr [eax*4 + a_arr]
/* 102:  3b c1 */               cmp        eax, ecx
/* 104:  74 24 */               je         _L12a
/* 106:  85 c0 */               test       eax, eax
/* 108:  7c 17 */               jl         _L121
/* 10a:  a1 10 00 00 03 */      mov        eax, dword ptr [c]
/* 10f:  85 c0 */               test       eax, eax
/* 111:  74 07 */               je         _L11a
/* 113:  e8 ec fe ff 02 */      call       branch1
/* 118:  eb 10 */               jmp        _L12a
_L11a:
/* 11a:  e8 ed fe ff 02 */      call       branch2
/* 11f:  eb 09 */               jmp        _L12a
_L121:
/* 121:  3b c1 */               cmp        eax, ecx
/* 123:  74 05 */               je         _L12a
/* 125:  e8 ea fe ff 02 */      call       branch3
_L12a:
/* 12a:  e9 ed fe ff 02 */      jmp        end


# RELOCATED SYMBOL MAPPING:
# a = 0x3000000
# branch1 = 0x3000004
# b = 0x3000008
# branch2 = 0x300000c
# c = 0x3000010
# branch3 = 0x3000014
# branch4 = 0x3000018
# end = 0x300001c
# a_arr = 0x3000020
