# Matching Notes
Notes on matching MSVC 98 assembly with C code and patterns that can be potentially spotted.

## Merged function calls with conditional argument
Sometimes code like this:
```c
if (foo != NULL) {
    someFunction(foo);
} else {
    someFunction(bar);
}
```
Will instead look like this:
```c
someFunction(foo != NULL ? foo : bar);
```
But will result in different assembly.
