import 'structured_file_reader.dart';

class OptionalHeader {
  /// State of the file.
  final int magic;

  /// Linker major version number.
  final int majorLinkerVersion;

  /// Linker minor version number.
  final int minorLinkerVersion;

  /// Size of the .text section or sum of all code sections.
  final int sizeOfCode;

  /// Size of the initialized data section (.data) or sum of all such sections.
  final int sizeOfInitializedData;

  /// Size of the uninitialized data section (.bss) or sum of all such sections.
  final int sizeOfUninitializedData;

  /// Address of the entry point, relative to the image base, when loaded into memory.
  ///
  /// Will be zero if no entry point is present.
  final int addressOfEntryPoint;

  /// Address, relative to the image base, of the start of the code section,
  /// when loaded into memory.
  final int baseOfCode;

  /// Address, relative to the image base, of the start of the data section,
  /// when loaded into memory.
  ///
  /// Unused for PE32+.
  final int baseOfData;

  /// Windows-specific header fields.
  final OptionalHeaderWindows? windows;

  /// Entries describing the address and size of a table or string available at runtime.
  final List<DataDirectory> dataDirectories;

  OptionalHeader({
    required this.magic,
    required this.majorLinkerVersion,
    required this.minorLinkerVersion,
    required this.sizeOfCode,
    required this.sizeOfInitializedData,
    required this.sizeOfUninitializedData,
    required this.addressOfEntryPoint,
    required this.baseOfCode,
    required this.baseOfData,
    required this.windows,
    required this.dataDirectories,
  });

  factory OptionalHeader.fromReader(
      StructuredFileReader reader, int optionalHeaderSize) {
    final magic = reader.readUint16();
    final majorLinkerVersion = reader.readUint8();
    final minorLinkerVersion = reader.readUint8();
    final sizeOfCode = reader.readUint32();
    final sizeOfInitializedData = reader.readUint32();
    final sizeOfUninitializedData = reader.readUint32();
    final addressOfEntryPoint = reader.readUint32();
    final baseOfCode = reader.readUint32();
    final baseOfData = magic == PEFormat.pe32Plus ? 0 : reader.readUint32();
    final OptionalHeaderWindows? windows;
    final List<DataDirectory> dataDirectories;

    if ((magic == PEFormat.pe32Plus && optionalHeaderSize > 24) ||
        (magic != PEFormat.pe32Plus && optionalHeaderSize > 28)) {
      // Windows-specific fields
      windows = OptionalHeaderWindows.fromReader(reader, magic);

      if ((magic == PEFormat.pe32Plus && optionalHeaderSize > 88) ||
          (magic != PEFormat.pe32Plus && optionalHeaderSize > 68)) {
        // Data directories
        dataDirectories = List.generate(windows.numberOfRvaAndSizes,
            (index) => DataDirectory.fromReader(reader));
      } else {
        dataDirectories = const [];
      }
    } else {
      windows = null;
      dataDirectories = const [];
    }

    return OptionalHeader(
      magic: magic,
      majorLinkerVersion: majorLinkerVersion,
      minorLinkerVersion: minorLinkerVersion,
      sizeOfCode: sizeOfCode,
      sizeOfInitializedData: sizeOfInitializedData,
      sizeOfUninitializedData: sizeOfUninitializedData,
      addressOfEntryPoint: addressOfEntryPoint,
      baseOfCode: baseOfCode,
      baseOfData: baseOfData,
      windows: windows,
      dataDirectories: dataDirectories,
    );
  }
}

/// Windows-specific optional header fields.
class OptionalHeaderWindows {
  /// Preferred address of the first byte of the image when loaded into memory.
  final int imageBase;

  /// Alignment (in bytes) of sections when loaded into memory.
  final int sectionAlignment;

  /// Alignment factor (in bytes) that is used to align the raw data of sections
  /// in the image file.
  final int fileAlignment;

  /// Major version number of the required operating system.
  final int majorOperatingSystemVersion;

  /// Minor version number of the required operating system.
  final int minorOperatingSystemVersion;

  /// Major version number of the image.
  final int majorImageVersion;

  /// Minor version number of the image.
  final int minorImageVersion;

  /// Major version number of the subsystem.
  final int majorSubsystemVersion;

  /// Minor version number of the subsystem.
  final int minorSubsystemVersion;

  /// Reserved.
  final int win32VersionValue;

  /// Size (in bytes) of the image, including all headers, as loaded in memory.
  final int sizeOfImage;

  /// Combined size of the MS-DOS stub, PE header, and section headers rounded up
  /// to a multiple of [fileAlignment].
  final int sizeOfHeaders;

  /// Image file checksum.
  final int checkSum;

  /// Subsystem required to run this image.
  ///
  /// See [SubsystemType].
  final int subsystem;

  /// Flags describing a DLL image.
  final DllCharacteristics dllCharacteristics;

  /// Size of the stack to reserve.
  final int sizeOfStackReserve;

  /// Size of the stack to commit.
  final int sizeOfStackCommit;

  /// Size of the local heap space to reserve.
  final int sizeOfHeapReserve;

  /// Size of the local heap space to commit.
  final int sizeOfHeapCommit;

  /// Reserved.
  final int loaderFlags;

  /// Number of data-directory entries.
  final int numberOfRvaAndSizes;

  OptionalHeaderWindows({
    required this.imageBase,
    required this.sectionAlignment,
    required this.fileAlignment,
    required this.majorOperatingSystemVersion,
    required this.minorOperatingSystemVersion,
    required this.majorImageVersion,
    required this.minorImageVersion,
    required this.majorSubsystemVersion,
    required this.minorSubsystemVersion,
    required this.win32VersionValue,
    required this.sizeOfImage,
    required this.sizeOfHeaders,
    required this.checkSum,
    required this.subsystem,
    required this.dllCharacteristics,
    required this.sizeOfStackReserve,
    required this.sizeOfStackCommit,
    required this.sizeOfHeapReserve,
    required this.sizeOfHeapCommit,
    required this.loaderFlags,
    required this.numberOfRvaAndSizes,
  });

  factory OptionalHeaderWindows.fromReader(StructuredFileReader reader, int magic) {
    final imageBase =
        magic == PEFormat.pe32Plus ? reader.readUint64() : reader.readUint32();
    final sectionAlignment = reader.readUint32();
    final fileAlignment = reader.readUint32();
    final majorOperatingSystemVersion = reader.readUint16();
    final minorOperatingSystemVersion = reader.readUint16();
    final majorImageVersion = reader.readUint16();
    final minorImageVersion = reader.readUint16();
    final majorSubsystemVersion = reader.readUint16();
    final minorSubsystemVersion = reader.readUint16();
    final win32VersionValue = reader.readUint32();
    final sizeOfImage = reader.readUint32();
    final sizeOfHeaders = reader.readUint32();
    final checkSum = reader.readUint32();
    final subsystem = reader.readUint16();
    final dllCharacteristics = reader.readUint16();
    final sizeOfStackReserve =
        magic == PEFormat.pe32Plus ? reader.readUint64() : reader.readUint32();
    final sizeOfStackCommit =
        magic == PEFormat.pe32Plus ? reader.readUint64() : reader.readUint32();
    final sizeOfHeapReserve =
        magic == PEFormat.pe32Plus ? reader.readUint64() : reader.readUint32();
    final sizeOfHeapCommit =
        magic == PEFormat.pe32Plus ? reader.readUint64() : reader.readUint32();
    final loaderFlags = reader.readUint32();
    final numberOfRvaAndSizes = reader.readUint32();

    return OptionalHeaderWindows(
      imageBase: imageBase,
      sectionAlignment: sectionAlignment,
      fileAlignment: fileAlignment,
      majorOperatingSystemVersion: majorOperatingSystemVersion,
      minorOperatingSystemVersion: minorOperatingSystemVersion,
      majorImageVersion: majorImageVersion,
      minorImageVersion: minorImageVersion,
      majorSubsystemVersion: majorSubsystemVersion,
      minorSubsystemVersion: minorSubsystemVersion,
      win32VersionValue: win32VersionValue,
      sizeOfImage: sizeOfImage,
      sizeOfHeaders: sizeOfHeaders,
      checkSum: checkSum,
      subsystem: subsystem,
      dllCharacteristics: DllCharacteristics(dllCharacteristics),
      sizeOfStackReserve: sizeOfStackReserve,
      sizeOfStackCommit: sizeOfStackCommit,
      sizeOfHeapReserve: sizeOfHeapReserve,
      sizeOfHeapCommit: sizeOfHeapCommit,
      loaderFlags: loaderFlags,
      numberOfRvaAndSizes: numberOfRvaAndSizes,
    );
  }
}

class DataDirectory {
  /// Data directory index for the export table.
  static const int exportTable = 0;

  /// Data directory index for the import table.
  static const int importTable = 1;

  /// Data directory index for the resource table.
  static const int resourceTable = 2;

  /// Data directory index for the exception table.
  static const int exceptionTable = 3;

  /// Data directory index for the attribute certificate table.
  static const int certificateTable = 4;

  /// Data directory index for the base relocation table.
  static const int baseRelocationTable = 5;

  /// Data directory index for the debug data starting address and size.
  static const int debug = 6;

  /// Reserved.
  static const int architecture = 7;

  /// Data directory index for the RVA of the value to be stored in the
  /// global pointer register.
  static const int globalPtr = 8;

  /// Data directory index for the thread local storage table.
  static const int tlsTable = 9;

  /// Data directory index for the load configuration table.
  static const int loadConfigTable = 10;

  /// Data directory index for the bound import table.
  static const int boundImport = 11;

  /// Data directory index for the import address table.
  static const int iat = 12;

  /// Data directory index for the delay import descriptor.
  static const int delayImportDescriptor = 13;

  /// Data directory index for the CLR runtime header.
  static const int clrRuntimeHeader = 14;

  /// Address of the data relative to the base address of the image when loaded.
  final int virtualAddress;

  /// The size of the data in bytes.
  final int size;

  DataDirectory({required this.virtualAddress, required this.size});

  factory DataDirectory.fromReader(StructuredFileReader reader) {
    final virtualAddress = reader.readUint32();
    final size = reader.readUint32();

    return DataDirectory(virtualAddress: virtualAddress, size: size);
  }
}

abstract class PEFormat {
  /// ROM image
  static const int rom = 0x107;

  /// Executable file (x86/any cpu)
  static const int pe32 = 0x10B;

  /// Executable file (x64)
  static const int pe32Plus = 0x20B;
}

abstract class SubsystemType {
  /// Unknown subsystem
  static const int unknown = 0x00;

  /// Device drivers and native Windows processes
  static const int native = 0x01;

  /// Windows graphical user interface subsystem
  static const int windowsGui = 0x02;

  /// Windows character subsystem
  static const int windowsCui = 0x03;

  /// OS/2 character subsystem
  static const int os2Cui = 0x05;

  /// Posix character subsystem
  static const int posixCui = 0x07;

  /// Native Win9x driver
  static const int windows9xNative = 0x08;

  /// Windows CE
  static const int windowsCeGui = 0x09;

  /// Extensible firmware interface application
  static const int efiApplication = 0x0A;

  /// EFI driver with boot services
  static const int efiBootServiceDriver = 0x0B;

  /// EFI driver with runtime services
  static const int efiRuntimeDriver = 0x0C;

  /// EFI ROM image
  static const int efiRom = 0x0D;

  /// XBOX
  static const int xbox = 0x0E;

  /// Windows boot application
  static const int windowsBootApplication = 0x10;
}

/// Flags describing a DLL image.
class DllCharacteristics {
  /// Image can handle a high entropy 64-bit virtual address space.
  bool get highEntropyVa => (rawValue & 0x0020) != 0;

  /// DLL can be relocated at load time.
  bool get dynamicBase => (rawValue & 0x0040) != 0;

  /// Code integrity checks are enforced.
  bool get forceIntegrity => (rawValue & 0x0080) != 0;

  /// Image is NX compatible.
  bool get nxCompatible => (rawValue & 0x0100) != 0;

  /// Isolation aware, but do not isolate the image.
  bool get noIsolation => (rawValue & 0x0200) != 0;

  /// Does not use structured exception (SE) handling.
  bool get noSeh => (rawValue & 0x0400) != 0;

  /// Do not bind the image.
  bool get doNotBind => (rawValue & 0x0800) != 0;

  /// Image must execute in an AppContainer.
  bool get appContainer => (rawValue & 0x1000) != 0;

  /// A WDM driver.
  bool get wdmDriver => (rawValue & 0x2000) != 0;

  /// Image supports Control Flow Guard.
  bool get cfGuard => (rawValue & 0x4000) != 0;

  /// Terminal Server aware.
  bool get terminalServerAware => (rawValue & 0x8000) != 0;

  final int rawValue;

  DllCharacteristics(this.rawValue);
}
