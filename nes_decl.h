
enum OpTypes {
    IMP = 1, NDX =  2, NDY =  3, ZP  =  4, ZPX =  5, ZPY =  6, IMM =  7,
    ABS = 8, ABX =  9, ABY = 10, ACC = 11, REL = 12, IND = 13,
};

// Инструкции
enum OpInstr {
    ___ = 0,  BRK = 1,  ORA = 2,  AND = 3,  EOR = 4,  ADC = 5,  STA = 6,  LDA = 7,
    CMP = 8,  SBC = 9,  BPL = 10, BMI = 11, BVC = 12, BVS = 13, BCC = 14, BCS = 15,
    BNE = 16, BEQ = 17, JSR = 18, RTI = 19, RTS = 20, LDY = 21, CPY = 22, CPX = 23,
    ASL = 24, PHP = 25, CLC = 26, BIT = 27, ROL = 28, PLP = 29, SEC = 30, LSR = 31,
    PHA = 32, PLA = 33, JMP = 34, CLI = 35, ROR = 36, SEI = 37, STY = 38, STX = 39,
    DEY = 40, TXA = 41, TYA = 42, TXS = 43, LDX = 44, TAY = 45, TAX = 46, CLV = 47,
    TSX = 48, DEC = 49, INY = 50, DEX = 51, CLD = 52, INC = 53, INX = 54, NOP = 55,
    SED = 56, AAC = 57, SLO = 58, RLA = 59, RRA = 60, SRE = 61, DCP = 62, ISC = 63,
    LAX = 64, AAX = 65, ASR = 66, ARR = 67, ATX = 68, AXS = 69, XAA = 70, AXA = 71,
    SYA = 72, SXA = 73, DOP = 74,
};

static const char* OPTABLE[256] =
{
    /*        00  01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F */
    /* 00 */ "BRK", "ORA", "___", "SLO", "DOP", "ORA", "ASL", "SLO", "PHP", "ORA", "ASL", "AAC", "DOP", "ORA", "ASL", "SLO",
    /* 10 */ "BPL", "ORA", "___", "SLO", "DOP", "ORA", "ASL", "SLO", "CLC", "ORA", "NOP", "SLO", "DOP", "ORA", "ASL", "SLO",
    /* 20 */ "JSR", "AND", "___", "RLA", "BIT", "AND", "ROL", "RLA", "PLP", "AND", "ROL", "AAC", "BIT", "AND", "ROL", "RLA",
    /* 30 */ "BMI", "AND", "___", "RLA", "DOP", "AND", "ROL", "RLA", "SEC", "AND", "NOP", "RLA", "DOP", "AND", "ROL", "RLA",
    /* 40 */ "RTI", "EOR", "___", "SRE", "DOP", "EOR", "LSR", "SRE", "PHA", "EOR", "LSR", "ASR", "JMP", "EOR", "LSR", "SRE",
    /* 50 */ "BVC", "EOR", "___", "SRE", "DOP", "EOR", "LSR", "SRE", "CLI", "EOR", "NOP", "SRE", "DOP", "EOR", "LSR", "SRE",
    /* 60 */ "RTS", "ADC", "___", "RRA", "DOP", "ADC", "ROR", "RRA", "PLA", "ADC", "ROR", "ARR", "JMP", "ADC", "ROR", "RRA",
    /* 70 */ "BVS", "ADC", "___", "RRA", "DOP", "ADC", "ROR", "RRA", "SEI", "ADC", "NOP", "RRA", "DOP", "ADC", "ROR", "RRA",
    /* 80 */ "DOP", "STA", "DOP", "AAX", "STY", "STA", "STX", "AAX", "DEY", "DOP", "TXA", "XAA", "STY", "STA", "STX", "AAX",
    /* 90 */ "BCC", "STA", "___", "AXA", "STY", "STA", "STX", "AAX", "TYA", "STA", "TXS", "AAX", "SYA", "STA", "SXA", "AAX",
    /* A0 */ "LDY", "LDA", "LDX", "LAX", "LDY", "LDA", "LDX", "LAX", "TAY", "LDA", "TAX", "ATX", "LDY", "LDA", "LDX", "LAX",
    /* B0 */ "BCS", "LDA", "___", "LAX", "LDY", "LDA", "LDX", "LAX", "CLV", "LDA", "TSX", "LAX", "LDY", "LDA", "LDX", "LAX",
    /* C0 */ "CPY", "CMP", "DOP", "DCP", "CPY", "CMP", "DEC", "DCP", "INY", "CMP", "DEX", "AXS", "CPY", "CMP", "DEC", "DCP",
    /* D0 */ "BNE", "CMP", "___", "DCP", "DOP", "CMP", "DEC", "DCP", "CLD", "CMP", "NOP", "DCP", "DOP", "CMP", "DEC", "DCP",
    /* E0 */ "CPX", "SBC", "DOP", "ISC", "CPX", "SBC", "INC", "ISC", "INX", "SBC", "NOP", "SBC", "CPX", "SBC", "INC", "ISC",
    /* F0 */ "BEQ", "SBC", "___", "ISC", "DOP", "SBC", "INC", "ISC", "SED", "SBC", "NOP", "ISC", "DOP", "SBC", "INC", "ISC"
};

// Имена инструкции
static const int opcode_names[256] = {

    /*        00  01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F */
    /* 00 */ BRK, ORA, ___, SLO, DOP, ORA, ASL, SLO, PHP, ORA, ASL, AAC, DOP, ORA, ASL, SLO,
    /* 10 */ BPL, ORA, ___, SLO, DOP, ORA, ASL, SLO, CLC, ORA, NOP, SLO, DOP, ORA, ASL, SLO,
    /* 20 */ JSR, AND, ___, RLA, BIT, AND, ROL, RLA, PLP, AND, ROL, AAC, BIT, AND, ROL, RLA,
    /* 30 */ BMI, AND, ___, RLA, DOP, AND, ROL, RLA, SEC, AND, NOP, RLA, DOP, AND, ROL, RLA,
    /* 40 */ RTI, EOR, ___, SRE, DOP, EOR, LSR, SRE, PHA, EOR, LSR, ASR, JMP, EOR, LSR, SRE,
    /* 50 */ BVC, EOR, ___, SRE, DOP, EOR, LSR, SRE, CLI, EOR, NOP, SRE, DOP, EOR, LSR, SRE,
    /* 60 */ RTS, ADC, ___, RRA, DOP, ADC, ROR, RRA, PLA, ADC, ROR, ARR, JMP, ADC, ROR, RRA,
    /* 70 */ BVS, ADC, ___, RRA, DOP, ADC, ROR, RRA, SEI, ADC, NOP, RRA, DOP, ADC, ROR, RRA,
    /* 80 */ DOP, STA, DOP, AAX, STY, STA, STX, AAX, DEY, DOP, TXA, XAA, STY, STA, STX, AAX,
    /* 90 */ BCC, STA, ___, AXA, STY, STA, STX, AAX, TYA, STA, TXS, AAX, SYA, STA, SXA, AAX,
    /* A0 */ LDY, LDA, LDX, LAX, LDY, LDA, LDX, LAX, TAY, LDA, TAX, ATX, LDY, LDA, LDX, LAX,
    /* B0 */ BCS, LDA, ___, LAX, LDY, LDA, LDX, LAX, CLV, LDA, TSX, LAX, LDY, LDA, LDX, LAX,
    /* C0 */ CPY, CMP, DOP, DCP, CPY, CMP, DEC, DCP, INY, CMP, DEX, AXS, CPY, CMP, DEC, DCP,
    /* D0 */ BNE, CMP, ___, DCP, DOP, CMP, DEC, DCP, CLD, CMP, NOP, DCP, DOP, CMP, DEC, DCP,
    /* E0 */ CPX, SBC, DOP, ISC, CPX, SBC, INC, ISC, INX, SBC, NOP, SBC, CPX, SBC, INC, ISC,
    /* F0 */ BEQ, SBC, ___, ISC, DOP, SBC, INC, ISC, SED, SBC, NOP, ISC, DOP, SBC, INC, ISC
};

// Типы операндов для каждого опкода
static const int operand_types[256] = {

    /*       00   01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F */
    /* 00 */ IMP, NDX, ___, NDX, ZP , ZP , ZP , ZP , IMP, IMM, ACC, IMM, ABS, ABS, ABS, ABS,
    /* 10 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* 20 */ ABS, NDX, ___, NDX, ZP , ZP , ZP , ZP , IMP, IMM, ACC, IMM, ABS, ABS, ABS, ABS,
    /* 30 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* 40 */ IMP, NDX, ___, NDX, ZP , ZP , ZP , ZP , IMP, IMM, ACC, IMM, ABS, ABS, ABS, ABS,
    /* 50 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* 60 */ IMP, NDX, ___, NDX, ZP , ZP , ZP , ZP , IMP, IMM, ACC, IMM, IND, ABS, ABS, ABS,
    /* 70 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* 80 */ IMM, NDX, IMM, NDX, ZP , ZP , ZP , ZP , IMP, IMM, IMP, IMM, ABS, ABS, ABS, ABS,
    /* 90 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPY, ZPY, IMP, ABY, IMP, ABY, ABX, ABX, ABY, ABX,
    /* A0 */ IMM, NDX, IMM, NDX, ZP , ZP , ZP , ZP , IMP, IMM, IMP, IMM, ABS, ABS, ABS, ABS,
    /* B0 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPY, ZPY, IMP, ABY, IMP, ABY, ABX, ABX, ABY, ABY,
    /* C0 */ IMM, NDX, IMM, NDX, ZP , ZP , ZP , ZP , IMP, IMM, IMP, IMM, ABS, ABS, ABS, ABS,
    /* D0 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* E0 */ IMM, NDX, IMM, NDX, ZP , ZP , ZP , ZP , IMP, IMM, IMP, IMM, ABS, ABS, ABS, ABS,
    /* F0 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX
};

// Количество циклов на опкод
static const int cycles_basic[256] = {

    7, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    6, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 3, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
    2, 6, 2, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5,
    2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
    2, 5, 2, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4,
    2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    2, 6, 3, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7
};

static const int palette[64] = {

    // 00-0F
    0x7B7B7B, 0x0000FF, 0x0000BD, 0x4229BD,
    0x940084, 0xAD0021, 0x8C1000, 0x8C1000,
    0x522900, 0x007300, 0x006B00, 0x005A00,
    0x004252, 0x000000, 0x000000, 0x000000,
    // 10-1F
    0xBDBDBD, 0x0073F7, 0x0052F7, 0x6B42FF,
    0xDE00CE, 0xE7005A, 0xF73100, 0xE75A10,
    0xAD7B00, 0x00AD00, 0x00AD00, 0x00AD42,
    0x008C8C, 0x000000, 0x000000, 0x000000,
    // 20-2F
    0xF7F7F7, 0x39BDFF, 0x6B84FF, 0x9473F7,
    0xF773F7, 0xF75294, 0xF77352, 0xFFA542,
    0xF7B500, 0xB5F710, 0x5ADE52, 0x52F794,
    0x00EFDE, 0x737373, 0x000000, 0x000000,
    // 30-3F
    0xFFFFFF, 0xA5E7FF, 0xB5B5F7, 0xD6B5F7,
    0xF7B5F7, 0xFFA5C6, 0xEFCEAD, 0xFFE7AD,
    0xFFDE7B, 0xD6F773, 0xB5F7B5, 0xB5F7D6,
    0x00FFFF, 0xF7D6F7, 0x000000, 0x000000
};

// Типы операндов для каждого опкода
static const int OPTYPES[256] =
{
    /*       00   01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F */
    /* 00 */ IMP, NDX, ___, NDX, ZP , ZP , ZP , ZP , IMP, IMM, ACC, IMM, ABS, ABS, ABS, ABS,
    /* 10 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* 20 */ ABS, NDX, ___, NDX, ZP , ZP , ZP , ZP , IMP, IMM, ACC, IMM, ABS, ABS, ABS, ABS,
    /* 30 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* 40 */ IMP, NDX, ___, NDX, ZP , ZP , ZP , ZP , IMP, IMM, ACC, IMM, ABS, ABS, ABS, ABS,
    /* 50 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* 60 */ IMP, NDX, ___, NDX, ZP , ZP , ZP , ZP , IMP, IMM, ACC, IMM, IND, ABS, ABS, ABS,
    /* 70 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* 80 */ IMM, NDX, IMM, NDX, ZP , ZP , ZP , ZP , IMP, IMM, IMP, IMM, ABS, ABS, ABS, ABS,
    /* 90 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPY, ZPY, IMP, ABY, IMP, ABY, ABX, ABX, ABY, ABX,
    /* A0 */ IMM, NDX, IMM, NDX, ZP , ZP , ZP , ZP , IMP, IMM, IMP, IMM, ABS, ABS, ABS, ABS,
    /* B0 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPY, ZPY, IMP, ABY, IMP, ABY, ABX, ABX, ABY, ABY,
    /* C0 */ IMM, NDX, IMM, NDX, ZP , ZP , ZP , ZP , IMP, IMM, IMP, IMM, ABS, ABS, ABS, ABS,
    /* D0 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX,
    /* E0 */ IMM, NDX, IMM, NDX, ZP , ZP , ZP , ZP , IMP, IMM, IMP, IMM, ABS, ABS, ABS, ABS,
    /* F0 */ REL, NDY, ___, NDY, ZPX, ZPX, ZPX, ZPX, IMP, ABY, IMP, ABY, ABX, ABX, ABX, ABX
};

// 44 байта https://audiocoding.ru/articles/2008-05-22-wav-file-structure/
struct __attribute__((__packed__)) WAVEFMTHEADER {

    unsigned int    chunkId;        // RIFF 0x52494646
    unsigned int    chunkSize;
    unsigned int    format;         // WAVE 0x57415645
    unsigned int    subchunk1Id;    // fmt (0x666d7420)
    unsigned int    subchunk1Size;  // 16
    unsigned short  audioFormat;    // 1
    unsigned short  numChannels;    // 2
    unsigned int    sampleRate;     // 44100
    unsigned int    byteRate;       // 88200
    unsigned short  blockAlign;     // 2
    unsigned short  bitsPerSample;  // 8
    unsigned int    subchunk2Id;    // data 0x64617461
    unsigned int    subchunk2Size;  // Количество байт в области данных.
};

// Значение длины периода ноты
static const int EAPU_Length[32] = {
//   0    1   2  3   4   5  6  7    8  9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24   25  26  27  28  29  30  31
    10, 254, 20, 2, 40, 80, 4, 6, 160, 8, 60, 10, 14, 12, 26, 14, 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30
};

static const int EAPU_duty[4] = {0x01, 0x03, 0x0F, 0xFC};

struct eAPU_square {

    int duty,    loop, cnst, vol;
    int sweep,   swperiod, negate, shift;
    int timer,   period, tmp;
    int counter, ac, out, decay;
    int env_c,   bitp;
};
