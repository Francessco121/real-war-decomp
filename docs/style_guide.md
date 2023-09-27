# Style Guide
Work in progress style guide for the Real War decompilation.

## Naming Conventions

### Functions
lower_snake_case

### Local variables
camelCase

### Global variables
camelCase with a `g` prefix, ex: `gVariableName`

### Static global variables
camelCase with an `s` prefix, ex: `sVariableName`

### String literal symbol
Snake case mostly consisting of the string's contents, prefixed with `str_`. For example, the string `Hello World\n` could have the variable name `str_Hello_World_nl`.

## Code Style

### Pointer syntax
The pointer asterisk should be next to the variable/function name, not the type. Example: `FILE *someFile;`.

### Global declarations
All declarations in header files should be prefixed with `extern`. Source files should not contain `extern` declarations. Instead, globals should be defined (without `extern`) with or without a value depending on if it's initialized data within a source file. For undefined globals that don't have their own header file, they should be placed in `undefined.h`.

Forward function declarations *within a source file* don't need the `extern` prefix.

### Header files
All header files must start with `#pragma once`.

## Symbols

### Unknown symbols
Unknown symbols should use the naming scheme `DAT_vaHexAddress` or `FUN_vaHexAddress` depending on if it's a global variable or function respectively.

### rw.yaml
Symbols in rw.yaml **MUST** be in ascending address order.

### String literals
Since the decomp doesn't support the use of static string literals, a symbol must be declared for them and used instead. These should be added to rw.yaml. After adding it, `strings.h` should be regenerated using the `rwyaml` tool.
