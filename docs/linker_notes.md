why:
- VS C++ 6.0 linker is too limited and doesn't give us a way to specify symbol locations,
  making it impossible to match functions that reference other functions and globals.

how:
- Let rw.yaml map out all of RealWar.exe, including:    
    - PE/COFF header, DOS header/stub
    - Image rich header
    - Section headers
    - .text segments (we make these up as we go)
    - .data segments (we make these up as we go)
    - .rdata segments (we make these up as we go)
    - .rsrc (maybe we recompile these ourselves some day)
- Let rw.yaml also map out symbol addresses for globals and functions so relocations can be applied
- Have a script extract data/code from the exe according to that map:
    - Extract 'bin' segments to .bin files
    - Extract 'asm' segments to .bin and disassembled .s files
    - Extract 'c' segments to disassembled .s files (no binary blob)
- To link, recreate a valid PE by:
    - Copying in original DOS header/sub
    - Writing out custom PE/COFF headers
    - Copying in original image rich header
    - Writing out custom section headers
    - Merging .text segments (binary/asm as is to designated addresses, c from compiled .obj file)
    - Merging .data segments (binary/asm as is to designated addresses, c from compiled .obj file)
    - Merging .rdata segments (binary/asm as is to designated addresses, c from compiled .obj file)
    - Copying original .rsrc section

notes:
- COFF and section headers will be adjusted if linked code changes the size of a section to assist
  with tooling, but resized sections will not be runnable since addresses from binary code will be wrong
- This approach is designed 100% for a verifiable decomp, not for modding. Patching in custom/new code
  for a partial decomp will have to be handled another way.
