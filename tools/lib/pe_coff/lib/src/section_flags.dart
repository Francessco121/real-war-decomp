// https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#section-flags

class SectionFlagValues {
  /// Obsolete.
  static const typeNoPad = 0x00000008;
  /// The section contains executable code. 
  static const cntCode = 0x00000020;
  /// The section contains initialized data. 
  static const cntInitializedData = 0x00000040;
  /// The section contains uninitialized data. 
  static const cntUninitializedData = 0x00000080;
  /// Reserved.
  static const lnkOther = 0x00000100;
  /// The section contains comments or other information.
  static const lnkInfo = 0x00000200;
  /// The section will not become part of the image.
  static const lnkRemove = 0x00000800;
  /// The section contains COMDAT data. 
  static const lnkComdat = 0x00001000;
  /// The section contains data referenced through the global pointer (GP).
  static const gprel = 0x00008000;
  /// Reserved.
  static const memPurgeable = 0x00020000;
  /// Reserved.
  static const memLocked = 0x00040000;
  /// Reserved.
  static const memPreload = 0x00080000;
  static const align1Bytes = 0x00100000;
  static const align2Bytes = 0x00200000;
  static const align4Bytes = 0x00300000;
  static const align8Bytes = 0x00400000;
  static const align16Bytes = 0x00500000;
  static const align32Bytes = 0x00600000;
  static const align64Bytes = 0x00700000;
  static const align128Bytes = 0x00800000;
  static const align256Bytes = 0x00900000;
  static const align512Bytes = 0x00A00000;
  static const align1024Bytes = 0x00B00000;
  static const align2048Bytes = 0x00C00000;
  static const align4096Bytes = 0x00D00000;
  static const align8192Bytes = 0x00E00000;
  /// The section contains extended relocations. 
  static const lnkNrelocOvfl = 0x01000000;
  /// The section can be discarded as needed. 
  static const memDiscardable = 0x02000000;
  /// The section cannot be cached. 
  static const memNotCached = 0x04000000;
  /// The section is not pageable. 
  static const memNotPaged = 0x08000000;
  /// The section can be shared in memory. 
  static const memShared = 0x10000000;
  /// The section can be executed as code. 
  static const memExecute = 0x20000000;
  /// The section can be read. 
  static const memRead = 0x40000000;
  /// The section can be written to. 
  static const memWrite = 0x80000000;
}

class SectionFlags {
  /// Obsolete.
  bool get typeNoPad => (rawValue & 0x00000008) != 0;
  /// The section contains executable code. 
  bool get cntCode => (rawValue & 0x00000020) != 0;
  /// The section contains initialized data. 
  bool get cntInitializedData => (rawValue & 0x00000040) != 0;
  /// The section contains uninitialized data. 
  bool get cntUninitializedData => (rawValue & 0x00000080) != 0;
  /// Reserved.
  bool get lnkOther => (rawValue & 0x00000100) != 0;
  /// The section contains comments or other information.
  bool get lnkInfo => (rawValue & 0x00000200) != 0;
  /// The section will not become part of the image.
  bool get lnkRemove => (rawValue & 0x00000800) != 0;
  /// The section contains COMDAT data. 
  bool get lnkComdat => (rawValue & 0x00001000) != 0;
  /// The section contains data referenced through the global pointer (GP).
  bool get gprel => (rawValue & 0x00008000) != 0;
  /// Reserved.
  bool get memPurgeable => (rawValue & 0x00020000) != 0;
  /// Reserved.
  bool get memLocked => (rawValue & 0x00040000) != 0;
  /// Reserved.
  bool get memPreload => (rawValue & 0x00080000) != 0;
  bool get align1Bytes => (rawValue & 0x00100000) != 0;
  bool get align2Bytes => (rawValue & 0x00200000) != 0;
  bool get align4Bytes => (rawValue & 0x00300000) != 0;
  bool get align8Bytes => (rawValue & 0x00400000) != 0;
  bool get align16Bytes => (rawValue & 0x00500000) != 0;
  bool get align32Bytes => (rawValue & 0x00600000) != 0;
  bool get align64Bytes => (rawValue & 0x00700000) != 0;
  bool get align128Bytes => (rawValue & 0x00800000) != 0;
  bool get align256Bytes => (rawValue & 0x00900000) != 0;
  bool get align512Bytes => (rawValue & 0x00A00000) != 0;
  bool get align1024Bytes => (rawValue & 0x00B00000) != 0;
  bool get align2048Bytes => (rawValue & 0x00C00000) != 0;
  bool get align4096Bytes => (rawValue & 0x00D00000) != 0;
  bool get align8192Bytes => (rawValue & 0x00E00000) != 0;
  /// The section contains extended relocations. 
  bool get lnkNrelocOvfl => (rawValue & 0x01000000) != 0;
  /// The section can be discarded as needed. 
  bool get memDiscardable => (rawValue & 0x02000000) != 0;
  /// The section cannot be cached. 
  bool get memNotCached => (rawValue & 0x04000000) != 0;
  /// The section is not pageable. 
  bool get memNotPaged => (rawValue & 0x08000000) != 0;
  /// The section can be shared in memory. 
  bool get memShared => (rawValue & 0x10000000) != 0;
  /// The section can be executed as code. 
  bool get memExecute => (rawValue & 0x20000000) != 0;
  /// The section can be read. 
  bool get memRead => (rawValue & 0x40000000) != 0;
  /// The section can be written to. 
  bool get memWrite => (rawValue & 0x80000000) != 0;

  final int rawValue;

  SectionFlags(this.rawValue);
}