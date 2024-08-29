#include <SDL2/SDL.h>

// =0 Verilog =1 C++
#define PPU_MODEL 1

// Дебаг CPU
#define DEBUG1 0

// Порты
#define DEBUG2 0

// Видео область
#define DEBUG3 0

enum OpTypes {
    ___ = 0,
    IMP = 1, NDX =  2, NDY =  3, ZP  =  4, ZPX =  5, ZPY =  6, IMM =  7,
    ABS = 8, ABX =  9, ABY = 10, ACC = 11, REL = 12, IND = 13,
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

class TB
{
protected:

    SDL_Surface*        screen_surface;
    SDL_Window*         sdl_window;
    SDL_Renderer*       sdl_renderer;
    SDL_PixelFormat*    sdl_pixel_format;
    SDL_Texture*        sdl_screen_texture;
    SDL_Event           evt;
    Uint32*             screen_buffer;

    // Обработка фрейма
    int width, height, scale, frame_length, pticks;
    int x, y, _hs, _vs, instr = 125000;

    uint8_t*    videom;
    uint8_t*    chrrom;
    uint8_t*    program;
    uint8_t     ram[2048];
    uint8_t     oam[256];
    uint8_t     x2line[256];
    uint8_t     joy1 = 0, joy2 = 0;

    // Эмулятор PPU
    int         vmemsize = 0x7FF;         // Зависит от маппера размер памяти
    uint8_t     _ppu_pa[32];
    int         _ppu_c0 = 0x10, _ppu_c1 = 0x00,
                _ppu_ff = 0x00, _ppu_vs = 0x00, // FineXFF, VSync
                _ppu_zh = 0x00, _ppu_ov = 0x00, // ZeroHit; Sprite Overflow
                _ppu_w  = 0x00, _ppu_sa = 0x00, // W, SpriteAddress
                _ppu_sd = 0x00, _ppu_fx = 0x00, // SpriteData, FineX
                _ppu_va = 0x00, _ppu_ch = 0x00, // CursorAddr, CharLatch
                _ppu_dm = 0x00;                 // DMA
    int         _ppu_j0, _ppu_j1, _ppu_j2,
                _ppu_v  = 0, _ppu_t  = 0,
                _ppu_px = 0, _ppu_py = 0,
                _ppu_cd = 0, _ppu_at = 0, _ppu_bk = 0;
    int         _ppu_bg[256];            // Одна линия (фон и спрайты)

    char        ds[256];

    int         cnt_prg_rom;
    int         cnt_chr_rom;

    // Модули
    Vppu*       ppu;
    Vcpu*       cpu;

public:

    TB(int argc, char** argv)
    {
        FILE* fp;
        uint8_t ines[16];

        x   = 0;
        y   = 2;
        _hs = 1;
        _vs = 0;

        Verilated::commandArgs(argc, argv);

        program = (uint8_t*) malloc(256*1024);
        chrrom  = (uint8_t*) malloc(128*1024);
        videom  = (uint8_t*) malloc(64*1024);

        scale        = 1;           // Удвоение пикселей
        width        = 640;         // Ширина экрана
        height       = 480;         // Высота экрана
        frame_length = (1000/20);   // 20 FPS
        pticks       = 0;

        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
            exit(1);
        }

        SDL_ClearError();
        sdl_window          = SDL_CreateWindow("SDL2", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, scale * width, scale * height, SDL_WINDOW_SHOWN);
        sdl_renderer        = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
        screen_buffer       = (Uint32*) malloc(width * height * sizeof(Uint32));
        sdl_screen_texture  = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, width, height);
        SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);

        // Модуль PPU
        ppu = new Vppu;
        cpu = new Vcpu;

        ppu->reset_n = 0;
        ppu->clock25 = 0; ppu->eval();
        ppu->clock25 = 1; ppu->eval();
        ppu->reset_n = 1;

        cpu->reset_n = 0;
        cpu->clock   = 0; cpu->eval();
        cpu->clock   = 1; cpu->eval();
        cpu->reset_n = 1;

        // Очистить память
        for (int i = 0; i < 256*1024; i++) program[i] = 0;

        // Инициализация
        _ppu_pa[ 0] = 0x0F; _ppu_pa[ 1] = 0x16; _ppu_pa[ 2] = 0x30; _ppu_pa[ 3] = 0x38;
        _ppu_pa[ 4] = 0x0F; _ppu_pa[ 5] = 0x16; _ppu_pa[ 6] = 0x26; _ppu_pa[ 7] = 0x07;
        _ppu_pa[ 8] = 0x0F; _ppu_pa[ 9] = 0x26; _ppu_pa[10] = 0x00; _ppu_pa[11] = 0x30;
        _ppu_pa[12] = 0x0F; _ppu_pa[13] = 0x38; _ppu_pa[14] = 0x28; _ppu_pa[15] = 0x00;

        _ppu_pa[16] = 0x0F; _ppu_pa[17] = 0x16; _ppu_pa[18] = 0x27; _ppu_pa[19] = 0x12;
        _ppu_pa[20] = 0x0F; _ppu_pa[21] = 0x30; _ppu_pa[22] = 0x2B; _ppu_pa[23] = 0x16;
        _ppu_pa[24] = 0x0F; _ppu_pa[25] = 0x39; _ppu_pa[26] = 0x28; _ppu_pa[27] = 0x27;
        _ppu_pa[28] = 0x0F; _ppu_pa[29] = 0x30; _ppu_pa[30] = 0x30; _ppu_pa[31] = 0x30;

        // Загрузка NES-файла
        if (argc > 1) {

            fp = fopen(argv[1], "rb");
            if (fp) {

                fread(ines, 1, 16, fp);

                cnt_prg_rom = ines[4];
                cnt_chr_rom = ines[5];

                // Читать программную память
                fread(program, 1, cnt_prg_rom * 16384, fp);

                if (cnt_prg_rom == 1) {
                    for (int i = 0; i < 0x4000; i++) {
                        program[i + 0x4000] = program[i];
                    }
                }

                // Читать память CHR
                fread(chrrom, cnt_chr_rom, 8192, fp);
                fclose(fp);

            } else {

                printf("No file\n");
                exit(1);
            }
        }

        // Загрузка CHR-ROM + VideoMemory
        if (argc > 2) {

            if (fp = fopen(argv[2], "rb")) {
                fread(videom, 1, 16384, fp);
                fclose(fp);
            }

        }

        // Загрузка OAM
        if (argc > 3) {

            if (fp = fopen(argv[3], "rb")) {
                fread(oam, 1, 256, fp);
                fclose(fp);
            }
        }
    }

    // Чтение из видеопамяти
    uint8_t readv(uint16_t A)
    {
        // Знакогенератор CHR-ROM и видеопамять для PPU
        if (A < 0x2000) {
            return chrrom[A];
        }
        // Зеркалирование VRAM [4 страницы] 2Dendy + 2Cartridge
        else if (A >= 0x2000 && A < 0x3F00) {
            return videom[0x2000 + (A & vmemsize)];
        }

        return 0xFF;
    }

    uint8_t read(uint16_t A)
    {
        // Оперативная память
        if (A < 0x2000) {
            return ram[A & 0x7FF];
        }
        // Память программ
        else if (A >= 0x8000) {
            return program[A & 0x7FFF];
        }

        return 0xFF;
    }

    // Писать можно только в память
    void write(uint16_t A, uint8_t D)
    {
        if (A < 0x2000) {
            ram[A & 0x7FF] = D;
        }
    }

    // 1 Такт CPU + PPU обвязка + VGA
    void tick()
    {
        // 0xFFF
        int vmemsize = 0x7FF;

        // Для сканлайна 25 Мгц тактируется
        if (ppu->x2w) { x2line[ppu->x2a] = ppu->x2o; }
        ppu->x2i = x2line[ppu->x2a];

        // --------------------------------
        ppu->chrd = readv(ppu->chra);

        // Запись в OAM
        if (ppu->oam2w) { oam[ppu->oam2a] = ppu->oam2o; }

        // Запись в видеопамять [4k]
        if (ppu->vida >= 0x2000 && ppu->vida < 0x3F00 && ppu->vidw) {
            videom[0x2000 + (ppu->vida & vmemsize)] = ppu->vido;
        }

        // Чтение OAM, CHR
        ppu->oamd  = oam[ppu->oama];
        ppu->oam2i = oam[ppu->oam2a];

        // Чтение CHR или ATTR для CPU: 1FFF
        if (ppu->vida >= 0x2000 && ppu->vida < 0x3F00) {
            ppu->vidi  = videom[0x2000 + (ppu->vida & vmemsize)];
        } else if (ppu->vida < 0x2000) {
            ppu->vidi  = videom[ppu->vida];
        }

        // -----------------------------------

        // Подготовка данных для PPU
        ppu->cpu_a = cpu->A;
        ppu->cpu_o = cpu->D;
        ppu->cpu_w = cpu->W;
        ppu->cpu_r = cpu->R;

        // Джойстики
        ppu->joy1 = joy1;
        ppu->joy2 = joy2;

        // Запись и чтение в зависимости от мапперов
        if (ppu->prgw) { write(ppu->prga, ppu->prgd); }

        // Читаться для PPU, не CPU.
        ppu->prgi = read(ppu->prga);

        // -- PPU здесь --
        ppu->clock25 = 0; ppu->eval();
        ppu->clock25 = 1; ppu->eval();

        // Для CPU данные готовятся в PPU
        cpu->I   = ppu->cpu_i;
        cpu->ce  = ppu->ce_cpu;
        cpu->nmi = ppu->nmi;

        debug();
        cpu->clock = 0; cpu->eval();
        cpu->clock = 1; cpu->eval();

        vga(ppu->hs, ppu->vs, ppu->r*16*65536 + ppu->g*16*256 + ppu->b*16);
    }

    // Работа только процессора [PPU эмулируется]
    void tick_emulated()
    {
        int A = cpu->A, D = cpu->D, W = cpu->W, R = cpu->R, I;

        // Запись или чтение в память
        if (W) { write(A, D); } I = read(A);

        // DMA запись
        if (A == 0x4014 && W) {

            for (int i = 0; i < 256; i++) {
                oam[i] = read(D*256 + i);
            }

            _ppu_dm = 255;
        }
        // Джойстики 1 и 2
        else if (A == 0x4016) {

            if (W) {

                // Защелка
                if (_ppu_j0 == 1 && (D & 1) == 0) {
                    _ppu_j1 = joy1 | 0x800;
                    _ppu_j2 = joy2 | 0x800;
                }

                _ppu_j0 = D & 1;

            } else if (R) {

                I = (_ppu_j1 & 1) | 0x40;

                _ppu_j1 >>= 1;
                _ppu_j2 >>= 1;
            }
        }
        // Запись или чтение в видеорегистры
        else if (A >= 0x2000 && A <= 0x3FFF) {

            switch (A & 7) {

                // #2000 CTRL0
                case 0: {

                    if (W) {
                        _ppu_c0 = D;
                        _ppu_t  = (_ppu_t & 0xF3FF) | ((D & 3) << 10); // Биты 11..10 в t
                    } else if (R) {
                        I = _ppu_c0;
                    }

                    break;
                }

                // #2001 CTRL1
                case 1: if (W) _ppu_c1 = D; else if (R) I = _ppu_c1; break;

                // #2002 STATUS
                case 2: {

                    if (R) {

                        I = (_ppu_vs << 7) | (_ppu_zh << 6) | (_ppu_ov << 5) | 0x10;

                        _ppu_vs = 0;
                        _ppu_zh = 0;
                        _ppu_w  = 0;
                    }

                    break;
                }

                // #2003 SPRITE_ADDR
                case 3: if (W) _ppu_sa = D; break;

                // #2004 SPRITE DATA
                case 4: {

                    if (W) {
                        oam[_ppu_sa] = _ppu_sd;
                    } else if (R) {
                        I = oam[_ppu_sa];
                    }

                    _ppu_sa = (_ppu_sa + 1) & 1;
                    break;
                }

                // #2005 SCROLL
                case 5: {

                    if (W) {

                        if (_ppu_w == 0) {
                            _ppu_ff = D & 7; // FineX
                            _ppu_t  = (_ppu_t & 0xFFE0) | ((D & 0xF8) >> 3); // CoarseX  D[7:3] -> T[4:0]
                        } else {
                            _ppu_t  = (_ppu_t & 0x8FFF) | ((D & 3) << 12);   // FineY:   D[2:0] -> T[14:12]
                            _ppu_t  = (_ppu_t & 0xFC1F) | ((D & 0xF8) << 2); // CoarseY: D[7:3] -> T[9:5]

                        }

                        _ppu_w ^= 1;
                    }

                    break;
                }

                // #2006 PPU ADDRESS
                case 6: {

                    if (W) {

                        if (_ppu_w == 0) {

                            _ppu_va = (_ppu_va & 0x00FF) | ((D & 0x7F) << 8); // D[6:0] -> VA[14:8]
                            _ppu_t  = (_ppu_t  & 0x00FF) | ((D & 0x3F) << 8); // D[5:0] -> T[13:8]; T[14] = 0

                        } else {

                            _ppu_va = (_ppu_va & 0xFF00) | (D & 0xFF); // D[7:0] -> VA[7:0]
                            _ppu_t  = (_ppu_t  & 0xFF00) | (D & 0xFF); // D[7:0] -> T[7:0]
                            _ppu_v  = _ppu_t;
                        }

                        _ppu_w ^= 1;
                    }

                    break;
                }

                // #2007 PPU DATA
                case 7: {

                    if (W) {

                        if (_ppu_va >= 0x3F00 && _ppu_va < 0x3F20) {
                            _ppu_pa[_ppu_va - 0x3F00] = D;
                        } else if (_ppu_va >= 0x2000 && _ppu_va < 0x3F00) {
                            videom[(_ppu_va & vmemsize) + 0x2000] = D;
                        }

                    } else if (R) {

                        // PALETTE
                        if (_ppu_va >= 0x3F00 && _ppu_va < 0x3F20) {
                            I = _ppu_pa[_ppu_va - 0x3F00];
                        }
                        // VIDEO MEMORY
                        else if (_ppu_va >= 0x2000 && _ppu_va < 0x3F00) {

                            I = _ppu_ch;
                            _ppu_ch = videom[(_ppu_va & vmemsize) + 0x2000];
                        }
                        // CHR-ROM
                        else if (_ppu_va < 0x2000) {
                            I = _ppu_ch;
                            _ppu_ch = videom[_ppu_va];
                        }
                    }

                    _ppu_va += (_ppu_c0 & 4 ? 32 : 1);
                    _ppu_va &= 0x3FFF;
                    break;
                }
            }
        }

        cpu->I  = I;
        cpu->ce = (_ppu_dm == 0) ? 1 : 0;

        // Уменьшать DMA циклы
        if (_ppu_dm) _ppu_dm--;

        debug();

        // Временно отключить
        // cpu->clock = 0; cpu->eval();
        // cpu->clock = 1; cpu->eval();

        // Обработка 3Т эмулятора PPU
        for (int i = 0; i < 3; i++) {

            int c;
            int nt = _ppu_v & 0xC00;        // Nametable [11:10]
            int cx = (_ppu_v     ) & 0x1F,  // CoarseX   [ 4:0]
                cy = (_ppu_v >> 5) & 0x1F;  // CoarseY   [ 9:5]

            // Чтение тайла при FineX = 0
            if (_ppu_fx == 0 && _ppu_px < 256) {

                // Чтение символа
                _ppu_cd =  0x2000 + cx + (cy << 5) + nt;
                _ppu_cd = readv(_ppu_cd);
                _ppu_cd = (_ppu_c0 & 0x10 ? 0x1000 : 0) + 16*_ppu_cd + ((_ppu_v >> 12) & 7);

                // Чтение битовой маски
                _ppu_bk = readv(_ppu_cd) + 256*readv(8 + _ppu_cd);

                // Запрос цветового атрибута
                _ppu_cd = 0x23C0 + ((cx >> 2) & 7) + 8*((cy >> 2) & 7) + nt;
                _ppu_cd = readv(_ppu_cd);
                _ppu_at = (_ppu_cd >> ((2*(cy & 2) | (cx & 2)))) & 3;

                // Смена NT [горизонтальный]
                if ((_ppu_v & 0x1F) == 0x1F) _ppu_v ^= 0x400;

                // Инкремент CoarseX
                _ppu_v = (_ppu_v & ~0x001F) | ((_ppu_v + 1) & 0x1F);
            }

            // Пиксель тайла, старший бит берется из старшего байта (аналогично младший)
            if (_ppu_px < 256 && _ppu_py < 240) {

                c = 7 - _ppu_fx;
                c = ((_ppu_bk >> c) & 1) + 2*((_ppu_bk >> (8 + c)) & 1);

                // Запись пикселя тайла на линию
                _ppu_bg[_ppu_px] = c ? 4*_ppu_at + c : 0;

                // FineX++
                _ppu_fx = (_ppu_fx + 1) & 7;
            }

            // Нарисовать тайлы и спрайты
            if (_ppu_px == 256) {

                _ppu_v  = (_ppu_v & ~0x0400) | (_ppu_t & 0x0400); // T[10]  -> V[10]
                _ppu_v  = (_ppu_v & ~0x001F) | (_ppu_t & 0x001F); // T[4:0] -> V[4:0]
                _ppu_fx = _ppu_ff;
                int fy  = (_ppu_v >> 12) & 7;

                if (fy == 7) {

                    // Смена NT [Vertical]
                    if      (cy == 29) { cy = 0; _ppu_v ^= 0x800; }
                    else if (cy == 31) { cy = 0; }
                    else cy++;

                    // CoarseY++
                    _ppu_v = (_ppu_v & ~0x03E0) | (cy << 5);
                }

                fy = (fy + 1) & 7;

                // FineY++
                _ppu_v = (_ppu_v & ~0x7000) | (fy << 12);

                // Высота спрайта либо 16, либо 8
                int sp_height = (_ppu_c0 & 0x20) ? 16 : 8;
                int sp_cnt = 0;

                _ppu_ov = 0;

                // Обработка спрайтов
                for (int j = 0; j < 256; j += 4) {

                    // Где спрайт начинается
                    int sp_y = _ppu_py - (oam[j] - 1);

                    // Рисовать спрайт на линии
                    if (sp_y >= 0 && sp_y < sp_height && sp_cnt < 8) {

                        int sp_ch = oam[j + 1];     // Иконка спрайта
                        int sp_at = oam[j + 2];     // Атрибуты
                        int sp_x  = oam[j + 3];     // Откуда начинается

                        // Отражение по вертикальной оси
                        if (sp_at & 0x80) sp_y = sp_height - 1 - sp_y;

                        // Цветовая палитра
                        int sp_a  = (sp_y & 7) + (_ppu_c0 & 8 ? 0x1000 : 0);
                        int sp_pl = (sp_at & 3);

                        if (_ppu_c0 & 0x20) { // 16x8
                            sp_a += ((sp_ch & 0xFE) << 4) + (sp_y & 8 ? 16 : 0);
                        } else { // 8x8
                            sp_a += (sp_ch << 4);
                        }

                        // Прочесть пиксельные данные
                        int sp_pp = readv(sp_a) + 256*readv(sp_a+8);

                        // Отрисовка 8 бит
                        for (int k = 0; k < 8; k++) {

                            int kx    = (sp_at & 0x40) ? k : (7-k);
                            int sp_cc = ((sp_pp >> kx) & 1) | 2*((sp_pp >> (8 + kx) & 1));

                            if (sp_cc) {
                                _ppu_bg[sp_x + k] = 16 + 4*sp_pl + sp_cc;
                            }
                        }

                        sp_cnt++;
                        if (sp_cnt) _ppu_ov = 1;
                    }

                }

                // Отрисовка линии
                for (int j = 0; j < 256; j++) {

                    int c = palette[_ppu_pa[ _ppu_bg[j] ]];
                    pset(64 + 2*j, 2*_ppu_py,   c); pset(65 + 2*j, 2*_ppu_py,   c);
                    pset(64 + 2*j, 2*_ppu_py+1, c); pset(65 + 2*j, 2*_ppu_py+1, c);
                }
            }

            // NMI
            if (_ppu_px == 1 && _ppu_py == 241) {
                _ppu_vs = 1;

                // cpu->nmi = _ppu_c0 & 0x80 ? 1 : 0;
            }

            // Последняя строчка кадра
            if (_ppu_px == 1 && _ppu_py == 260) {

                // 14:11, 9:5 :: 0yyy u0YY YYY0 0000
                _ppu_v  = (_ppu_v & ~0x7BE0) | (_ppu_t & 0x7BE0);
                _ppu_vs = 0;
                _ppu_zh = 0;

                cpu->nmi = 0;
            }

            _ppu_px++;

            // Отсчет тактов
            if (_ppu_px == 341) {
                _ppu_px = 0;
                _ppu_py++;
                if (_ppu_py == 262) {
                    _ppu_py = 0;
                }
            }
        }
    }

    void debug()
    {
        if (DEBUG3 && ppu->vidw) {
            printf("%04X %02X\n", ppu->vida, ppu->vido);
        }

        // Отладка джойстика
        if (DEBUG2 && cpu->A == 0x4014 && (cpu->R || cpu->W)) {
            printf("%c %02X %02X\n", cpu->W ? 'w' : ' ', cpu->D, cpu->I);
        }

        // Состояние ДО выполнения такта CPU
        if (DEBUG1 && cpu->ce) {

            disam(cpu->A);
            printf("%c%04X R-%02X %s%02X R:[%02X %02X %02X %02X] V:[%04X %c] %c %s\n",
                (cpu->m0 ? '*' : ' '),
                cpu->A,
                cpu->I,
                (cpu->W ? "W-" : "  "),
                cpu->D,
                // --
                cpu->_a, cpu->_x, cpu->_y, cpu->_p,
                //
                ppu->vida,
                (ppu->vidw ? '~' : ' '),
                (cpu->nmi ? 'N' : ' '),
                cpu->m0 ? ds : ""
            );
        }
    }

    // Основной цикл работы
    int main()
    {
        SDL_Rect dstRect;

        dstRect.x = 0;
        dstRect.y = 0;
        dstRect.w = scale * width;
        dstRect.h = scale * height;

        for (;;) {

            Uint32 ticks = SDL_GetTicks();
            Uint32 count = 0;

            // Прием событий
            while (SDL_PollEvent(& evt)) {

                // Событие выхода
                switch (evt.type) {

                    case SDL_QUIT:

                        return 0;

                    case SDL_KEYDOWN:

                        kbd_scancode(evt.key.keysym.scancode, 1);
                        break;

                    case SDL_KEYUP:

                        kbd_scancode(evt.key.keysym.scancode, 0);
                        break;
                }
            }

            do {

                for (int i = 0; i < 4096; i++) {

                    if (PPU_MODEL) tick_emulated(); else tick();
                    count++;
                }

                pticks = SDL_GetTicks();

            } while (pticks - ticks < frame_length);

            SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, width * sizeof(Uint32));
            SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
            SDL_RenderClear         (sdl_renderer);
            SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, & dstRect);
            SDL_RenderPresent       (sdl_renderer);

            SDL_Delay(1);

            return 1;
        }
    }

    void kbd_scancode(int scan, int press)
    {
        switch (scan) {

            case SDL_SCANCODE_X:        joy1 = (joy1 & 0b11111110) | (press ? 1    : 0); break;
            case SDL_SCANCODE_Z:        joy1 = (joy1 & 0b11111101) | (press ? 2    : 0); break;
            case SDL_SCANCODE_C:        joy1 = (joy1 & 0b11111011) | (press ? 4    : 0); break;
            case SDL_SCANCODE_V:        joy1 = (joy1 & 0b11110111) | (press ? 8    : 0); break;
            case SDL_SCANCODE_UP:       joy1 = (joy1 & 0b11101111) | (press ? 16   : 0); break;
            case SDL_SCANCODE_DOWN:     joy1 = (joy1 & 0b11011111) | (press ? 32   : 0); break;
            case SDL_SCANCODE_LEFT:     joy1 = (joy1 & 0b10111111) | (press ? 64   : 0); break;
            case SDL_SCANCODE_RIGHT:    joy1 = (joy1 & 0b01111111) | (press ? 128  : 0); break;
        }
    }

    // Убрать окно из памяти
    int destroy()
    {
        free(screen_buffer);
        SDL_DestroyTexture(sdl_screen_texture);
        SDL_FreeFormat(sdl_pixel_format);
        SDL_DestroyRenderer(sdl_renderer);
        SDL_DestroyWindow(sdl_window);
        SDL_Quit();
        return 0;
    }

    // Установка точки
    void pset(int x, int y, Uint32 cl)
    {
        if (x < 0 || y < 0 || x >= width || y >= height) {
            return;
        }

        screen_buffer[width*y + x] = cl;
    }

    // Отслеживание сигнала RGB по HS/VS
    void vga(int hs, int vs, int cl) {

        // Отслеживание на фронтах HS/VS
        if (hs) x++;

        if (_hs == 1 && hs == 0) { x = 0; y++; }
        if (_vs == 1 && vs == 0) { y = 0; }

        _hs = hs;
        _vs = vs;

        // Вывод на экран
        pset(x-48-2, y-33-2, cl);
    }

    void disam(int a)
    {
        int a1 = read(a),
            a2 = read(a + 1),
            a3 = read(a + 2);

        switch (OPTYPES[a1])
        {
            case IMP: sprintf(ds, "%s",             OPTABLE[a1]); break;
            case NDX: sprintf(ds, "%s ($%02X+X)",   OPTABLE[a1], a2); break;
            case NDY: sprintf(ds, "%s ($%02X),Y",   OPTABLE[a1], a2); break;
            case ZP:  sprintf(ds, "%s ($%02X)",     OPTABLE[a1], a2); break;
            case ZPX: sprintf(ds, "%s ($%02X+X)",   OPTABLE[a1], a2); break;
            case ZPY: sprintf(ds, "%s ($%02X+Y)",   OPTABLE[a1], a2); break;
            case IMM: sprintf(ds, "%s #%02X",       OPTABLE[a1], a2); break;
            case ABS: sprintf(ds, "%s $%04X",       OPTABLE[a1], a2 + a3*256); break;
            case ABX: sprintf(ds, "%s $%04X,X",     OPTABLE[a1], a2 + a3*256); break;
            case ABY: sprintf(ds, "%s $%04X,Y",     OPTABLE[a1], a2 + a3*256); break;
            case ACC: sprintf(ds, "%s A",           OPTABLE[a1]); break;
            case REL: sprintf(ds, "%s $%04X",       OPTABLE[a1], a + 2 + (char)a2); break;
            case IND: sprintf(ds, "%s ($%04X)",     OPTABLE[a1], a2 + a3*256); break;
        }
    }
};
