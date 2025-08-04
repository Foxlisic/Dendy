#include <verilated.h>
#include "obj_dir/Vcpu.h"
#include "obj_dir/Vppu.h"

// ---------------------------
// Порты $4000-$4FFFF
#define DEBUG2 0
// Отладка APU
#define DEBUG3 0
// ---------------------------

#include "nes_decl.h"
#include "nes_tb.h"
#include "nes_cpu.cc"
#include "nes_ppu.cc"
#include "nes_apu.cc"
#include "nes_iface.cc"

TB::TB(int argc, char** argv)
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

    scale        = 2;           // Удвоение пикселей
    width        = 640;         // Ширина экрана
    height       = 480;         // Высота экрана
    frame_length = (1000/20);   // 20 FPS
    pticks       = 0;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
        exit(1);
    }

    SDL_ClearError();
    sdl_window          = SDL_CreateWindow("Nintendo Entertainment System", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, scale * width, scale * height, SDL_WINDOW_SHOWN);
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

    int i = 1;

    // Загрузка NES-файла
    while (i < argc) {

        // Загрузка параметра
        if (argv[i][0] == '-')
        {
            switch (argv[i][1])
            {
                // Загрузка CHR-ROM + VideoMemory
                case 'c':

                    if (fp = fopen(argv[++i], "rb")) {
                        fread(videom, 1, 16384, fp);
                        fclose(fp);
                    }

                    break;

                // Загрузка OAM
                case 'o':

                    if (fp = fopen(argv[++i], "rb")) {
                        fread(oam, 1, 256, fp);
                        fclose(fp);
                    }

                    break;

                // Установка уровня дебага процессора
                case 'd':

                    debug1_cpu = argv[i][2] - '0';
                    break;

                // Установка уровня эмулятора
                // =0 Чистый верилог
                // =1 PPU на C++
                // =2 PPU и CPU на C++
                case 'p':

                    ppu_model = argv[i][2] - '0';
                    break;
            }

        } else {

            fp = fopen(argv[i], "rb");
            if (fp) {

                fread(ines, 1, 16, fp);

                // Прочесть заголовок
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

                // Дублировать 16К картридж до 32К
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

                printf("ROM file error\n");
                exit(1);
            }
        }

        i++;
    }

    // Установка PC на начало программы
    pc = program[0x7FFC] + 256*program[0x7FFD];

    wavStart("nes.wav");
}

int main(int argc, char** argv)
{
    TB* tb = new TB(argc, argv);
    while (tb->main());
    return tb->destroy();
}
