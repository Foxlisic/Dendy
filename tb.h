#include <SDL2/SDL.h>

#define DEBUG1 0
#define DEBUG2 0

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

        for (int i = 0; i < 256*1024; i++) program[i] = 0;

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

                    tick();
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

    // Обработка одного фрейма
    // Автоматическая коррекция кол-ва инструкции в секунду
    void frame()
    {
        float target = 80; // X% CPU

        Uint32 start = SDL_GetTicks();
        for (int i = 0; i < instr; i++) {
            tick();
        }

        Uint32 delay = (SDL_GetTicks() - start);
        instr = (instr * (0.5 * target) / (float)delay);
        instr = instr < 1000 ? 1000 : instr;
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

    // 1 Такт
    void tick()
    {
        // Для сканлайна 25 Мгц тактируется
        if (ppu->x2w) { x2line[ppu->x2a] = ppu->x2o; }
        ppu->x2i = x2line[ppu->x2a];

        uint16_t PA = ppu->chra;

        // Знакогенератор CHR-ROM и видеопамять для PPU
        if (PA < 0x2000) {
            ppu->chrd = chrrom[PA];
        } else if (PA < 0x3F00) {
            ppu->chrd = videom[(PA & 0x07FF) | 0x2000]; // Зеркалирование VRAM [2 страницы]
        }

        // Запись в OAM
        if (ppu->oam2w) { oam[ppu->oam2a] = ppu->oam2o; }

        // Запись в видеопамять
        if (ppu->vida >= 0x2000 && ppu->vida < 0x3000 && ppu->vidw) {
            videom[0x2000 + (ppu->vida & 0x1FFF)] = ppu->vido;
        }

        // Чтение OAM, CHR
        ppu->oamd  = oam[ppu->oama];
        ppu->oam2i = oam[ppu->oam2a];

        // Чтение CHR или ATTR для CPU
        if (ppu->vida >= 0x2000 && ppu->vida < 0x3000) {
            ppu->vidi  = videom[0x2000 + (ppu->vida & 0x1FFF)];
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

        // Читаться для PPU, не CPU.
        ppu->prgi = read(ppu->prga);

        // Запись и чтение в зависимости от мапперов
        if (ppu->prgw) { write(ppu->prga, ppu->prgd); }

        // -- PPU здесь --
        ppu->clock25 = 0; ppu->eval();
        ppu->clock25 = 1; ppu->eval();

        // Для CPU данные готовятся в PPU
        cpu->I   = ppu->cpu_i;
        cpu->ce  = ppu->ce_cpu;
        cpu->nmi = ppu->nmi;

        // Отладка джойстика
        if (DEBUG2 && cpu->A == 0x4014 && (cpu->R || cpu->W)) {
            printf("%c %02X %02X\n", cpu->W ? 'w' : ' ', cpu->D, cpu->I);
        }

        // Состояние ДО выполнения такта CPU
        if (DEBUG1 && cpu->ce) {

            disam(cpu->A);
            printf("%c%04X R-%02X %s%02X A-%02X X-%02X Y-%02X P-%02X [%04X %c] %s\n",
                (cpu->m0 ? '*' : ' '),
                cpu->A,
                cpu->I,
                (cpu->W ? "W-" : "  "),
                cpu->D,
                // --
                cpu->_a, cpu->_x, cpu->_y, cpu->_p,
                //
                ppu->vida,
                (cpu->nmi ? 'w' : ' '),
                cpu->m0 ? ds : ""
            );
        }

        cpu->clock = 0; cpu->eval();
        cpu->clock = 1; cpu->eval();

        vga(ppu->hs, ppu->vs, ppu->r*16*65536 + ppu->g*16*256 + ppu->b*16);
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
            case NDX: sprintf(ds, "%s (%02X+X)",    OPTABLE[a1], a2); break;
            case NDY: sprintf(ds, "%s (%02X),Y",    OPTABLE[a1], a2); break;
            case ZP:  sprintf(ds, "%s (%02X)",      OPTABLE[a1], a2); break;
            case ZPX: sprintf(ds, "%s (%02X+X)",    OPTABLE[a1], a2); break;
            case ZPY: sprintf(ds, "%s (%02X+Y)",    OPTABLE[a1], a2); break;
            case IMM: sprintf(ds, "%s #%02X",       OPTABLE[a1], a2); break;
            case ABS: sprintf(ds, "%s #%04X",       OPTABLE[a1], a2 + a3*256); break;
            case ABX: sprintf(ds, "%s #%04X,X",     OPTABLE[a1], a2 + a3*256); break;
            case ABY: sprintf(ds, "%s #%04X,Y",     OPTABLE[a1], a2 + a3*256); break;
            case ACC: sprintf(ds, "%s A",           OPTABLE[a1]); break;
            case REL: sprintf(ds, "%s #%04X",       OPTABLE[a1], a + 2 + (char)a2); break;
            case IND: sprintf(ds, "%s (%04X)",      OPTABLE[a1], a2 + a3*256); break;
        }
    }
};
