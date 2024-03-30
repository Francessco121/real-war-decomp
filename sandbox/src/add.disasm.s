add:
/* 0:  8b 44 24 08 */           mov        eax, dword ptr [esp + 8]
/* 4:  8b 4c 24 04 */           mov        ecx, dword ptr [esp + 4]
/* 8:  03 c1 */                 add        eax, ecx
/* a:  c3 */                    ret        


# RELOCATED SYMBOL MAPPING:
