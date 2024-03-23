#define SDL_MAIN_HANDLED

#include <stdlib.h>
#include "obj_dir/Vnes.h"
#include "obj_dir/Vppu.h"

#include <SDL2/SDL.h>
#include <stdlib.h>
#include <stdio.h>

class App {
protected:

    SDL_Window*         sdl_window;
    SDL_Renderer*       sdl_renderer;
    SDL_Texture*        sdl_screen_texture;
    Uint32*             screen_buffer;

    Uint32  width, height, _scale, _width, _height;
    Uint32  frame_id;
    Uint32  frame_length;
    Uint32  frame_prev_ticks;

    Vnes*   mod_nes;
    Vppu*   mod_ppu;

    int     x, y, _hs, _vs;
    uint8_t vram[2048], chrom[8192], ram[2048], prg[32768];

public:

    // -----------------------------------------------------------------------------
    // ОБЩИЕ МЕТОДЫ
    // -----------------------------------------------------------------------------

    App(int w, int h, int scale = 2, int fps = 25) {

        _scale   = scale;
        _width   = w;
		 width   = w * scale;
        _height  = h;
		 height  = h * scale;
        frame_id = 0;

        _hs = 1; _vs = 0; x = 0; y = 0;

        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
            exit(1);
        }

        SDL_ClearError();
        sdl_window          = SDL_CreateWindow("DENDY: НОВАЯ РЕАЛЬНОСТЬ", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_SHOWN);
        sdl_renderer        = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_PRESENTVSYNC);
        screen_buffer       = (Uint32*) malloc(_width * _height * sizeof(Uint32));
        sdl_screen_texture  = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, _width, _height);
        SDL_SetTextureBlendMode(sdl_screen_texture, SDL_BLENDMODE_NONE);

        // Настройка FPS
        frame_length     = 1000 / (fps ? fps : 1);
        frame_prev_ticks = SDL_GetTicks();

        FILE* fp = fopen("out/record.ppm", "w");
        if (fp) fclose(fp);

        mod_nes = new Vnes;
        mod_ppu = new Vppu;
    }

    // Ожидание событий
    int main() {

        SDL_Event evt;

        for (;;) {

            Uint32 ticks = SDL_GetTicks();

            // Ожидать наступления события
            while (SDL_PollEvent(& evt)) {

                switch (evt.type) {

                    // Выход из программы по нажатии "крестика"
                    case SDL_QUIT: return 0;
                }
            }

            // Истечение таймаута: обновление экрана
            if (ticks - frame_prev_ticks >= frame_length) {

                frame_prev_ticks = ticks;
                update();
                return 1;
            }

            SDL_Delay(1);
        }
    }

    // Обновить окно
    void update() {

        SDL_Rect dstRect;

        dstRect.x = 0;
        dstRect.y = 0;
        dstRect.w = width;
        dstRect.h = height;

        SDL_UpdateTexture       (sdl_screen_texture, NULL, screen_buffer, _width * sizeof(Uint32));
        SDL_SetRenderDrawColor  (sdl_renderer, 0, 0, 0, 0);
        SDL_RenderClear         (sdl_renderer);
        SDL_RenderCopy          (sdl_renderer, sdl_screen_texture, NULL, & dstRect);
        SDL_RenderPresent       (sdl_renderer);
    }

    // Уничтожение окна
    int destroy() {

        if (sdl_screen_texture) { SDL_DestroyTexture(sdl_screen_texture);   sdl_screen_texture  = NULL; }
        if (sdl_renderer)       { SDL_DestroyRenderer(sdl_renderer);        sdl_renderer        = NULL; }

        free(screen_buffer);

        SDL_DestroyWindow(sdl_window);
        SDL_Quit();

        return 0;
    }

    // -----------------------------------------------------------------------------
    // ФУНКЦИИ РИСОВАНИЯ
    // -----------------------------------------------------------------------------

    // Установка точки
    void pset(int x, int y, Uint32 cl) {

        if (x < 0 || y < 0 || x >= _width || y >= _height)
            return;

        screen_buffer[y*_width + x] = cl;
    }

    // Отслеживание сигнала RGB по HS/VS; save=1 сохранить фрейм как ppm, 2=как png
    void vga(int hs, int vs, int color) {

        if (hs) x++;

        // Отслеживание изменений HS/VS
        if (_hs == 0 && hs == 1) { x = 0; y++; }
        if (_vs == 0 && vs == 1) { x = 0; y = 0; saveframe(); }

        // Сохранить предыдущее значение
        _hs = hs;
        _vs = vs;

        // Вывод на экран
        pset(x - 48, y - 33, color);
    }

    // Сохранение фрейма
    void saveframe() {

        char fn[256];

        FILE* fp = fopen("out/record.ppm", "ab");
        if (fp) {

            fprintf(fp, "P6\n# Verilator\n%d %d\n255\n", _width, _height);
            for (int y = 0; y < _height; y++)
            for (int x = 0; x < _width; x++) {

                int cl = screen_buffer[y*_width + x];
                int vl = ((cl >> 16) & 255) + (cl & 0xFF00) + ((cl&255)<<16);
                fwrite(&vl, 1, 3, fp);
            }

            fclose(fp);
        }

        frame_id++;
    }

	// Основной обработчик (TOP-уровень)
	void tick() {

		// Обработка PPU такта
		mod_ppu->clock = 0; mod_ppu->eval();
		mod_ppu->clock = 1; mod_ppu->eval();

		// Обработка CPU такта
		mod_nes->clock = 0; mod_nes->eval();
		mod_nes->clock = 1; mod_nes->eval();

		vga(mod_ppu->HS, mod_ppu->VS, 65536*(mod_ppu->R << 4) + 256*(mod_ppu->G << 4) + (mod_ppu->B << 4));
	}
};

// Главный цикл работы программы
int main(int argc, char **argv) {

    // -------------------------------------
    Verilated::commandArgs(argc, argv);
    App* app = new App(640, 480);
    // -------------------------------------

    while (app->main()) {
        for (int i = 0; i < 150000; i++)
            app->tick();
    }

    return app->destroy();
}
