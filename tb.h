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
    int width, height, scale, frame_length, pticks;
    int x, y, _hs, _vs, instr = 125000;

    uint8_t*    videom;
    uint8_t*    chrrom;
    uint8_t*    program;
    uint8_t     ram[2048];
    uint8_t     oam[256];
    uint8_t     x2line[256];

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
                fread(program + 0xC000, cnt_prg_rom, 16384, fp);

                if (cnt_prg_rom == 1) {
                    for (int i = 0; i < 0x4000; i++) {
                        program[i + 0x8000] = program[i + 0xC000];
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

            // Прием событий
            while (SDL_PollEvent(& evt)) {

                // Событие выхода
                switch (evt.type) {

                    case SDL_QUIT:
                        return 0;
                }
            }

            // Обновление экрана
            if (ticks - pticks >= frame_length) {

                frame();

                pticks = ticks;
                SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, width * sizeof(Uint32));
                SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
                SDL_RenderClear         (sdl_renderer);
                SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, & dstRect);
                SDL_RenderPresent       (sdl_renderer);

                return 1;
            }

            SDL_Delay(1);
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

        // Знакогенератор CHR-ROM и видеопамять
        if (PA < 0x2000) {
            ppu->chrd = chrrom[PA];
        } else if (PA < 0x3F00) {
            ppu->chrd = videom[(PA & 0x07FF) | 0x2000]; // Зеркалирование VRAM [2 страницы]
        }

        // Чтение OAM
        ppu->oamd = oam[ppu->oama];

        // -----------------------------------

        // -- PPU здесь --
        ppu->clock25 = 0; ppu->eval();
        ppu->clock25 = 1; ppu->eval();

        // Запись и чтение в зависимости от мапперов
        if (ppu->prgw) { write(ppu->prga, ppu->prgd); }

        // Читаться для PPU, не CPU.
        ppu->prgi = read(ppu->prga);

        // Для CPU данные готовятся в PPU
        cpu->I   = ppu->cpu_i;
        cpu->ce  = ppu->ce_cpu;
        cpu->nmi = ppu->nmi;
        cpu->clock = 0; cpu->eval();
        cpu->clock = 1; cpu->eval();

        // Подготовка данных для PPU
        ppu->cpu_a = cpu->A;
        ppu->cpu_o = cpu->D;
        ppu->cpu_w = cpu->W;
        ppu->cpu_r = cpu->R;

        // Состояние после выполнения такта CPU. R показывает на следующие данные для чтения
        if (0 && cpu->ce) printf("%c%04x R-%02x %s%02x\n", (cpu->m0 ? '*' : ' '), cpu->A, cpu->I, (cpu->W ? "W-" : "  "), cpu->D);

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
};
