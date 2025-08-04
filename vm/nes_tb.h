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
    int         cycles_count = 0;

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
    int         debug1_cpu = 0;
    int         ppu_model  = 0;

    int         cnt_prg_rom;
    int         cnt_chr_rom;

    int         mapper      = 0;
    int         mapper_chrw = 1;
    int         mapper_cw   = 0;
    int         mapper_nt   = 3;
    int         prg_bank    = 0;
    int         _cpu_m0     = 0;

    // Звук
    FILE*       wave_fp = NULL;
    uint        wav_size = 0;
    int         wav_timer = 0;

    eAPU_square     square[2];
    eAPU_triangle   triangle;
    int             eapu_cycle = 0;

    // Модули
    Vppu*       ppu;
    Vcpu*       cpu;

public:

    // Декларации
    TB(int argc, char** argv);

    // iface.cc :: Исполнение кода =============================================
    uint8_t readv(uint16_t A);
    uint8_t read(uint16_t A);
    void    write(uint16_t A, uint8_t D);
    int     tick();

    // ppu.cc :: Видеопроцессор ================================================
    int     eppu_rw(int A, int I, int R, int W, int D);
    int     tick_emulated();

    // apu.cc :: Звук ==========================================================
    void    wavStart(const char* filename);
    void    wavStop();
    uint8_t eApu(uint16_t A, uint8_t D, uint8_t I, int W, int R);

    // cpu.cc :: Процессор =====================================================

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

    void debug()
    {
        // Отладка джойстика
        if (DEBUG2 && cpu->ce && cpu->A >= 0x4000 && cpu->A < 0x4014 && (cpu->R || cpu->W)) {
            printf("%04X: %c %02X __ %08b\n", cpu->A, cpu->W ? 'W' : ' ', cpu->D, cpu->D);
        }

        // Состояние ДО выполнения такта CPU
        if (debug1_cpu) {

            if (ppu_model == 2) {

                disam(pc);
                printf("%04X %s\n", pc, ds);

            } else if (cpu->ce && ((debug1_cpu == 2) && cpu->m0 || debug1_cpu == 1)) {

                disam(cpu->A);

                // Cycles Bank:PC Read Write [A X Y P] Vida px py NMI
                printf("%08X %c%1X:%04X %02X %s%02X [%02X %02X %02X %02X] V-%04X%c {%03d %03d} %c | %s\n",
                    cycles_count,
                    (cpu->m0 && debug1_cpu == 1 ? '^' : ' '),
                    prg_bank,
                    cpu->A,
                    cpu->I,
                    (cpu->W ? ">" : " "),
                    cpu->D,
                    // --
                    cpu->a, cpu->x, cpu->y, cpu->p,
                    //
                    (ppu_model == 1 ? _ppu_dm : ppu->vida),
                    (ppu->vidw ? '~' : ' '),
                    ppu->px,
                    ppu->py,
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
                    if (ppu_model && count >= 107210) { SDL_Delay(1); break; }

                    // Выполнить такт
                    if (ppu_model) count += tick_emulated(); else count += tick();
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

    // Прочесть сканкод с клавиатуры
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
        wavStop();
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

    // Дизассемблировать адрес
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

};
