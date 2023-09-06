struct IMAGE_SEPARATE_DEBUG_HEADER {
    char signature[2];
    u16 flags;
    u16 machine;
    u16 characteristics;
    u32 timeDateStamp;
    u32 checkSum;
    u32 imageBase;
    u32 sizeOfImage;
    u32 numberOfSections;
    u32 exportedNamesSize;
    u32 debugDirectorySize;
    u32 sectionAlignment;
    u32 reserved[2];
};

enum AlignmentType : u8 {
	None,
	BoundaryOf1Byte,
	BoundaryOf2Bytes,
	BoundaryOf4Bytes,
	BoundaryOf8Bytes,
	BoundaryOf16Bytes,
	BoundaryOf32Bytes,
	BoundaryOf64Bytes,
	BoundaryOf128Bytes,
	BoundaryOf256Bytes,
	BoundaryOf512Bytes,
	BoundaryOf1024Bytes,
	BoundaryOf2048Bytes,
	BoundaryOf4096Bytes,
	BoundaryOf8192Bytes,
};

fn formatAlignmentBits(u8 value) {
	AlignmentType enumValue = value;

	return enumValue;
};

bitfield SectionFlags {
	padding : 3;
	doNotPad : 1;
	padding : 1;
	containsCode : 1;
	containsInitializedData : 1;
	containsUninitializedData : 1;
	linkOther : 1;
	containsComments : 1;
	padding : 1;
	remove : 1;
	containsCOMDATData : 1;
	padding : 2;
	globalPointerRelocation : 1;
	purgeable : 1;
	is16Bit : 1;
	locked : 1;
	preloaded : 1;
	dataAlignment : 4 [[format("formatAlignmentBits")]];
	extendedRelocations : 1;
	discardable : 1;
	notCacheable : 1;
	notPageable : 1;
	shared : 1;
	executed : 1;
	read : 1;
	writtenTo : 1;
};

struct IMAGE_SECTION_HEADER {
    char name[8];
    u32 physicalAddress;
    u32 virtualAddress;
    u32 sizeOfRawData;
    u32 pointerToRawData;
    u32 pointerToRelocations;
    u32 pointerToLinenumbers;
    u16 numberOfRelocations;
    u16 numberOfLinenumbers;
    SectionFlags characteristics;
};

enum DebugDirectoryType : u32 {
    unknown = 0,
    coff,
    codeView,
    fpo,
    misc,
    exception,
    fixUp,
    omapToSrc,
    omapFromSrc,
    borland,
    reserved
};

struct OMFSignature {
    char signature[4];
    u32 filePos;
};

enum DebugMiscDataType : u32 {
    exeName = 1
};

struct IMAGE_DEBUG_MISC {
    DebugMiscDataType dataType;
    u32 length;
    u8 unicode;
    u8 reserved[3];
    if (dataType == DebugMiscDataType::exeName) {
        if (unicode) {
            char16 exeName[length];
        }
        else {
            char exeName[length];
        }
    } else {
        u8 data[length];
    }
};

struct CodeView {
    OMFSignature signature;
};

struct IMAGE_DEBUG_DIRECTORY {
    u32 characteristics;
    u32 timeDateStamp;
    u16 majorVersion;
    u16 minorVersion;
    DebugDirectoryType type;
    u32 sizeOfData;
    u32 addressOfRawData;
    u32 pointerToRawData;
    match (type) {
        (DebugDirectoryType::misc): IMAGE_DEBUG_MISC misc @ pointerToRawData;
        (DebugDirectoryType::codeView): CodeView codeView @ pointerToRawData;
        (_): u8 data[sizeOfData] @ pointerToRawData;
    }
};



IMAGE_SEPARATE_DEBUG_HEADER header @ 0x0;
IMAGE_SECTION_HEADER sections[header.numberOfSections] @ $;
// 28 = sizeof(IMAGE_DEBUG_DIRECTORY)
IMAGE_DEBUG_DIRECTORY debugDirectories[header.debugDirectorySize / 28] @ $;