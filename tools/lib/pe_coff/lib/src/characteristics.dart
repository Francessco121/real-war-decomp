// https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#characteristics

/// Flags that indicate attributes of object or image files.
class Characteristics {
  /// Relocation information stripped from the file.
  bool get relocsStripped => (rawValue & 0x0001) != 0;
  /// File is executable (i.e., no unresolved external references).
  bool get executableImage => (rawValue & 0x0002) != 0;
  /// Line numbers stripped from the file.
  bool get lineNumsStripped => (rawValue & 0x0004) != 0;
  /// Local symbols stripped from the file.
  bool get localSymsStripped => (rawValue & 0x0008) != 0;
  /// Obsolete. Aggressively trim working set.
  bool get aggressiveWsTrim => (rawValue & 0x0010) != 0;
  /// Application can handle > 2-GB addresses.
  bool get largeAddressAware => (rawValue & 0x0020) != 0;
  /// Reserved for future use.
  bool get $16BitMachine => (rawValue & 0x0040) != 0;
  /// Obsolete. LSB precedes MSB in memory.
  bool get bytesReversedLo => (rawValue & 0x0080) != 0;
  /// Machine is based on a 32-bit-word architecture. 
  bool get $32BitMachine => (rawValue & 0x0100) != 0;
  /// Debugging information is removed from the image file. 
  bool get debugStripped => (rawValue & 0x0200) != 0;
  /// If the image is on removable media, fully load it and copy it to the swap file. 
  bool get removableRunFromSwap => (rawValue & 0x0400) != 0;
  /// If the image is on network media, fully load it and copy it to the swap file. 
  bool get netRunFromSwap => (rawValue & 0x0800) != 0;
  /// The image file is a system file, not a user program. 
  bool get system => (rawValue & 0x1000) != 0;
  /// The image file is a dynamic-link library (DLL).
  bool get dll => (rawValue & 0x2000) != 0;
  /// The file should be run only on a uniprocessor machine. 
  bool get upSystemOnly => (rawValue & 0x4000) != 0;
  /// Obsolete. MSB precedes LSB in memory.
  bool get bytesReversedHi => (rawValue & 0x8000) != 0;

  final int rawValue;

  Characteristics(this.rawValue);
}