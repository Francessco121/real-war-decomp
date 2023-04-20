// https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#machine-types

/// Machine (CPU) type.
abstract class MachineType {
  /// Applicable to any machine type
  static const int unknown = 0x0;
  /// Alpha AXP, 32-bit address space
  static const int alpha = 0x184;
  /// Alpha 64, 64-bit address space
  /// 
  /// Also AXP 64
  static const int alpha64 = 0x284;
  /// Matsushita AM33
  static const int am33 = 0x01D3;
  /// x64
  static const int amd64 = 0x8664;
  /// ARM little endian
  static const int arm = 0x01C0;
  /// ARM64 little endian
  static const int arm64 = 0xAA64;
  /// ARM Thumb-2 little endian
  static const int armNt = 0x01C4;
  /// EFI byte code
  static const int ebc = 0x0EBC;
  /// Intel 386 or later processors and compatible processors
  static const int i386 = 0x014C;
  /// Intel Itanium processor family 
  static const int ia64 = 0x0200;
  /// LoongArch 32-bit processor family 
  static const int loongArch32 = 0x6232;
  /// LoongArch 64-bit processor family 
  static const int loongArch64 = 0x6264;
  /// Mitsubishi M32R little endian 
  static const int m32r = 0x9041;
  /// Motorola 68000 series
  static const int m68k = 0x0268;
  /// MIPS16
  static const int mips16 = 0x0226;
  /// MIPS with FPU
  static const int mipsFpu = 0x0366;
  /// MIPS16 with FPU
  static const int mipsFpu16 = 0x0466;
  /// IBM Power PC little endian 
  static const int powerPc = 0x01F0;
  /// IBM Power PC with floating point support 
  static const int powerPcFp = 0x01F1;
  /// MIPS
  static const int r3000 = 0x0162;
  /// MIPS little endian
  static const int r4000 = 0x0166;
  /// MIPS
  static const int r10000 = 0x0168;
  /// RISC-V 32-bit address space 
  static const int riscv32 = 0x5032;
  /// RISC-V 64-bit address space 
  static const int riscv64 = 0x5064;
  /// RISC-V 128-bit address space 
  static const int riscv128 = 0x5128;
  /// Hitachi SH3
  static const int sh3 = 0x01A2;
  /// Hitachi SH3 DSP
  static const int sh3dsp = 0x01A3;
  /// Hitachi SH4
  static const int sh4 = 0x01A6;
  /// Hitachi SH5
  static const int sh5 = 0x01A8;
  /// Thumb
  static const int thumb = 0x01C2;
  /// MIPS little endian WCE v2
  static const int wceMipsV2 = 0x0169;
}
