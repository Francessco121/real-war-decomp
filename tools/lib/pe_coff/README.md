# pe_coff
A native Dart parser for Windows Portable Executable (PE) and Common Object File Format (COFF) files.

## Example
```dart
final peFile = File('./SomeProgram.exe');
final bytes = await file.readAsBytes();
final pe = PeFile.fromList(bytes);

print(pe.coffHeader.numberOfSections);
```
