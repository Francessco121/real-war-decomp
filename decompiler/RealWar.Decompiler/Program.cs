using System;
using System.IO;
using Gee.External.Capstone;
using Gee.External.Capstone.X86;

namespace RealWar.Decompiler;

class Program
{
    public static void Main(string[] args)
    {
        const int RAM_BASE = 0x00400000;
        const int TEXT_BASE = RAM_BASE + 0x1000;

        const int FUNCTION_RAM_START_ADDR = 0x004e318c;
        const int FUNCTION_RAM_END_ADDR = 0x004e31c4;

        byte[] exe = File.ReadAllBytes("../Game/RealWar.exe");

        using var cs = CapstoneDisassembler.CreateX86Disassembler(X86DisassembleMode.Bit32);

        int start = FUNCTION_RAM_START_ADDR - RAM_BASE;
        int end = FUNCTION_RAM_END_ADDR - RAM_BASE;

        cs.EnableInstructionDetails = true;
        foreach (var i in cs.Disassemble(exe[start..end], FUNCTION_RAM_START_ADDR))
        {
            Console.WriteLine($"0x{i.Address:x}:\t{i.Mnemonic}\t{i.Operand}");
        }
    }
}
