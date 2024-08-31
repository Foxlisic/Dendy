#include <SDL2/SDL.h>

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
    int         width, height, scale, frame_length, pticks;
    int         x, y, _hs, _vs, instr = 125000;
    int         tick_count = 0;

    uint8_t*    videom;
    uint8_t*    chrrom;
    uint8_t*    program;
    uint8_t     ram[2048];
    uint8_t     oam[256];
    uint8_t     x2line[256];
    uint8_t     joy1 = 0, joy2 = 0;

    // CPU
    uint8_t     reg_a, reg_x, reg_y, reg_p, reg_s;
    uint16_t    pc;
    int         cycles_ext = 0;
    int         dbgfx = 0;

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

    int         mapper      = 0;
    int         mapper_chrw = 1;
    int         prg_bank    = 0;
    int         _cpu_m0     = 0;

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

                // Номер маппера
                mapper      = (ines[6] >> 4) | (ines[7] & 0xF0);
                prg_bank    = cnt_prg_rom - 1;

                printf("PRGROM %d\n", cnt_prg_rom);
                printf("CHRROM %d\n", cnt_chr_rom);
                printf("Mapper %d\n", mapper);

                // Читать программную память
                fread(program, 1, cnt_prg_rom * 16384, fp);

                if (cnt_prg_rom == 1) {
                    for (int i = 0; i < 0x4000; i++) {
                        program[i + 0x4000] = program[i];
                    }
                }

                // Читать память CHR
                if (cnt_chr_rom) {
                    fread(chrrom, cnt_chr_rom, 8192, fp);
                }

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

        pc = program[0x7FFC] + 256*program[0x7FFD];
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
        if (DEBUG1) {

            if (PPU_MODEL == 2) {

                disam(pc);
                printf("%04X %s\n", pc, ds);

            } else if (cpu->ce || PPU_MODEL == 1) {

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
                    (PPU_MODEL == 1 ? _ppu_dm : ppu->vida),
                    (ppu->vidw ? '~' : ' '),
                    (cpu->nmi ? 'N' : ' '),
                    cpu->m0 ? ds : ""
                );
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

                    // Ограничить количество тактов :: 107210
                    if (PPU_MODEL && count >= 107210) { SDL_Delay(1); break; }

                    // Выполнить такт
                    if (PPU_MODEL) count += tick_emulated(); else count += tick();
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

    void disam(uint16_t a)
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

    // Декларации

    // iface.cc :: Исполнение кода
    uint8_t readv(uint16_t A);
    uint8_t read(uint16_t A);
    void    write(uint16_t A, uint8_t D);
    int     tick();

    // ppu.cc :: Видеопроцессор
    int     eppu_rw(int A, int I, int R, int W, int D);
    int     tick_emulated();

    // cpu.cc :: Процессор

    // Установка флагов
    void    set_zero(int x);
    void    set_overflow(int x);
    void    set_carry(int x);
    void    set_decimal(int x);
    void    set_break(int x);
    void    set_interrupt(int x);
    void    set_sign(int x);

    // Получение значений флагов
    int     if_carry();
    int     if_zero();
    int     if_interrupt();
    int     if_overflow();
    int     if_sign();

    // Работа со стеком
    void     push(int x);
    int      pull();
    uint16_t readw(int addr);
    int      effective(int addr);
    int      branch(int addr, int iaddr);
    void     brk();
    void     nmi();
    int      step();
};
