// https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#storage-class

/// Represents what kind of definition a symbol represents.
abstract class StorageClass {
  /// A special symbol that represents the end of function, for debugging purposes. 
  static const int endOfFunction = -1;
  /// No assigned storage class. 
  static const int null$ = 0;
  /// The automatic (stack) variable. The Value field specifies the stack frame offset. 
  static const int automatic = 1;
  /// A value that Microsoft tools use for external symbols. The Value field indicates 
  /// the size if the section number is 0 (undefined). If the section number is not zero, 
  /// then the Value field specifies the offset within the section. 
  static const int external = 2;
  /// The offset of the symbol within the section. If the Value field is zero, then the 
  /// symbol represents a section name. 
  static const int static = 3;
  /// A register variable. The Value field specifies the register number. 
  static const int register = 4;
  /// A symbol that is defined externally. 
  static const int externalDef = 5;
  /// A code label that is defined within the module. The Value field specifies the offset 
  /// of the symbol within the section. 
  static const int label = 6;
  /// A reference to a code label that is not defined. 
  static const int undefinedLabel = 7;
  /// The structure member. The Value field specifies the n th member. 
  static const int memberOfStruct = 8;
  /// A formal argument (parameter) of a function. The Value field specifies the nth argument. 
  static const int argument = 9;
  /// The structure tag-name entry. 
  static const int structTag = 10;
  /// A union member. The Value field specifies the nth member. 
  static const int memberOfUnion = 11;
  /// The Union tag-name entry. 
  static const int unionTag = 12;
  /// A typedef entry. 
  static const int typeDefinition = 13;
  /// A static data declaration. 
  static const int undefinedStatic = 14;
  /// An enumerated type tagname entry. 
  static const int enumTag = 15;
  /// A member of an enumeration. The Value field specifies the nth member. 
  static const int memberOfEnum = 16;
  /// A register parameter. 
  static const int registerParam = 17;
  /// A bit-field reference. The Value field specifies the nth bit in the bit field. 
  static const int bitField = 18;
  /// A .bb (beginning of block) or .eb (end of block) record. The Value field is the relocatable 
  /// address of the code location. 
  static const int block = 100;
  /// A value that Microsoft tools use for symbol records that define the extent of a function: 
  /// begin function (.bf ), end function ( .ef ), and lines in function ( .lf ). 
  /// For .lf records, the Value field gives the number of source lines in the function. 
  /// For .ef records, the Value field gives the size of the function code. 
  static const int function = 101;
  /// An end-of-structure entry. 
  static const int endOfStruct = 102;
  /// A value that Microsoft tools, as well as traditional COFF format, use for the source-file 
  /// symbol record. The symbol is followed by auxiliary records that name the file. 
  static const int file = 103;
  /// A definition of a section (Microsoft tools use [static] storage class instead). 
  static const int section = 104;
  /// A weak external.
  static const int weakExternal = 105;
  /// A CLR token symbol. The name is an ASCII string that consists of the hexadecimal value of the token.
  static const int clrToken = 107;
}
