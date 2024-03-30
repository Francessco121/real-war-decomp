set:
/* 0:  8b 44 24 04 */           mov        eax, dword ptr [esp + 4]
/* 4:  c7 00 05 00 00 00 */     mov        dword ptr [eax], 5
/* a:  c3 */                    ret        


main:
/* 10:  51 */                   push       ecx
/* 11:  8d 44 24 00 */          lea        eax, [esp]
/* 15:  50 */                   push       eax
/* 16:  e8 e5 ff ff 00 */       call       set
/* 1b:  83 c4 08 */             add        esp, 8
/* 1e:  c3 */                   ret        


# RELOCATED SYMBOL MAPPING:
# set = 0x1000000
