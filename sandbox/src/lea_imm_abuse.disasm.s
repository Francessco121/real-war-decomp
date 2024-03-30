func1:
/* 0:  8b 44 24 08 */           mov        eax, dword ptr [esp + 8]
/* 4:  8b 4c 24 04 */           mov        ecx, dword ptr [esp + 4]
/* 8:  8b 54 24 0c */           mov        edx, dword ptr [esp + 0xc]
/* c:  03 c8 */                 add        ecx, eax
/* e:  8d 44 11 02 */           lea        eax, [ecx + edx + 2]
/* 12:  c3 */                   ret        


func2:
/* 20:  8b 44 24 08 */          mov        eax, dword ptr [esp + 8]
/* 24:  8b 4c 24 04 */          mov        ecx, dword ptr [esp + 4]
/* 28:  8d 44 01 02 */          lea        eax, [ecx + eax + 2]
/* 2c:  c3 */                   ret        


func3:
/* 30:  8b 44 24 04 */          mov        eax, dword ptr [esp + 4]
/* 34:  83 c0 02 */             add        eax, 2
/* 37:  c3 */                   ret        


# RELOCATED SYMBOL MAPPING:
