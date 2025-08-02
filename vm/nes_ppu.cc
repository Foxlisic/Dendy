// Обращение к эмулятору PPU
int TB::eppu_rw(int A, int I, int R, int W, int D)
{
    // DMA запись
    if (A == 0x4014 && W && _ppu_dm == 0 && cpu->ce) {

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
        }
    }
    // Запись или чтение в видеорегистры
    else if (A >= 0x2000 && A <= 0x3FFF) {

        ppu->vida = _ppu_va;

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
                        _ppu_t  = (_ppu_t & ~0x001F) | ((D & 0xF8) >> 3); // CoarseX  D[7:3] -> T[4:0]
                    } else {
                        _ppu_t  = (_ppu_t & ~0x7000) | ((D & 3) << 12);   // FineY:   D[2:0] -> T[14:12]
                        _ppu_t  = (_ppu_t & ~0x03E0) | ((D & 0xF8) << 2); // CoarseY: D[7:3] -> T[9:5]
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

                    if (_ppu_va >= 0x3F00 && _ppu_va < 0x4000) {
                        if ((_ppu_va & 0x1F) == 0x10) {
                            _ppu_pa[0] = D;
                        } else {
                            _ppu_pa[_ppu_va & 0x1F] = D;
                        }
                    } else if (_ppu_va >= 0x2000 && _ppu_va < 0x3F00) {
                        videom[(_ppu_va & vmemsize) + 0x2000] = D;
                    }

                } else if (R) {

                    // PALETTE
                    if (_ppu_va >= 0x3F00 && _ppu_va < 0x4000) {
                        I = _ppu_va & 0x1F;
                        I = _ppu_pa[I == 16 ? 0 : I];
                    }
                    // VIDEO MEMORY
                    else if (_ppu_va < 0x3F00) {

                        I = _ppu_ch;
                        _ppu_ch = readv(_ppu_va);
                    }
                }

                _ppu_va += (_ppu_c0 & 4 ? 32 : 1);
                _ppu_va &= 0x3FFF;
                break;
            }
        }
    }

    return I;
}

// Работа только процессора [PPU эмулируется]
int TB::tick_emulated()
{
    int A, D, W, R, I;
    int cycles = 1;

    // Эмулятор процессора
    if (ppu_model == 2) {

        debug();
        cycles = step();

    } else if (ppu_model == 1) {

        A = cpu->A;
        D = cpu->D;
        W = cpu->W;
        R = cpu->R;

        // Запись или чтение в память
        if (W) { write(A, D); } I = read(A);

        // Операция чтения или записи в PPU
        I = eppu_rw(A, I, R, W, D);

        cpu->I  = I;
        cpu->ce = (_ppu_dm == 0) ? 1 : 0;

        debug();
        cpu->clock = 0; cpu->eval();
        cpu->clock = 1; cpu->eval();
    }

    // Уменьшать DMA циклы
    if (_ppu_dm > 0) _ppu_dm--;

    // Обработка 3Т эмулятора PPU
    for (int i = 0; i < 3 * cycles; i++) {

        int c;
        int nt = _ppu_v & 0xC00;        // Nametable [11:10]
        int cx = (_ppu_v     ) & 0x1F,  // CoarseX   [ 4:0]
            cy = (_ppu_v >> 5) & 0x1F;  // CoarseY   [ 9:5]

        // Нарисовать пиксель тайла [пререндер первого тайла]
        if (_ppu_px >= 8 && _ppu_px < (8+256) && _ppu_py < 240) {

            // Фон не отображается
            if ((_ppu_c1 & 0x08) == 0) _ppu_bk = 0;

            // Фон не виден в левом углу
            if ((_ppu_c1 & 0x02) == 0 && _ppu_px < 8) _ppu_bk = 0;

            c = 7 - _ppu_fx;
            c = ((_ppu_bk >> c) & 1) + 2*((_ppu_bk >> (8 + c)) & 1);

            // Запись пикселя тайла на линию
            _ppu_bg[_ppu_px - 8] = c ? 4*_ppu_at + c : 0;
        }

        // Чтение тайла при FineX = 7
        if (_ppu_fx == 7 && _ppu_px < (256+8)) {

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

        // Инкремент FineX
        if (_ppu_px < (256+8)) _ppu_fx = (_ppu_fx + 1) & 7;

        // Нарисовать тайлы и спрайты
        if (_ppu_px == 340) {

            _ppu_v  = (_ppu_v & ~0x0400) | (_ppu_t & 0x0400); // T[ 10] -> V[ 10]
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
            if (_ppu_c1 & 0x10)
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

                    // 16x8 или 8x8
                    if (_ppu_c0 & 0x20) {
                        sp_a += ((sp_ch & 0xFE) << 4) + (sp_y & 8 ? 16 : 0);
                    } else {
                        sp_a += (sp_ch << 4);
                    }

                    // Прочесть пиксельные данные
                    int sp_pp = readv(sp_a) + 256*readv(sp_a+8);

                    // Отрисовка 8 бит
                    for (int k = 0; k < 8; k++) {

                        int kx    = (sp_at & 0x40) ? k : (7-k);
                        int sp_cc = ((sp_pp >> kx) & 1) | 2*((sp_pp >> (8 + kx) & 1));

                        if (sp_cc) {

                            int bk = _ppu_bg[sp_x + k];
                            int fr = sp_at & 0x20 ? 1 : 0;

                            // Спрайт за фоном или перед фоном
                            if (fr && (bk & 0b10011 == 0) || !fr) {
                                _ppu_bg[sp_x + k] = 16 + 4*sp_pl + sp_cc;
                            }

                            // Достигнут Sprite0Hit
                            if (j == 0) _ppu_zh = 1;
                        }
                    }

                    sp_cnt++;
                    if (sp_cnt) _ppu_ov = 1;
                }
            }

            // Только на видимой области
            if (_ppu_py < 240) {

                // Отрисовка линии
                for (int j = 0; j < 256; j++) {

                    int c = palette[_ppu_pa[ _ppu_bg[j] ]];
                    pset(64 + 2*j, 2*_ppu_py,   c); pset(65 + 2*j, 2*_ppu_py,   c);
                    pset(64 + 2*j, 2*_ppu_py+1, c); pset(65 + 2*j, 2*_ppu_py+1, c);
                }

                // Бордер
                for (int j = 0; j < 64; j++) {

                    pset(j, 2*_ppu_py,   palette[_ppu_pa[0]]);
                    pset(j, 2*_ppu_py+1, palette[_ppu_pa[0]]);

                    pset(j + 512+64, 2*_ppu_py,   palette[_ppu_pa[0]]);
                    pset(j + 512+64, 2*_ppu_py+1, palette[_ppu_pa[0]]);
                }
            }
        }

        // NMI: Возникает на 240-й линии
        if (_ppu_px == 1 && _ppu_py == 240) {

            _ppu_vs = 1;
            cpu->nmi = _ppu_c0 & 0x80 ? 1 : 0;

            // NMI запрос для эмулятора
            if (ppu_model == 2 && cpu->nmi) nmi();
        }

        // Последняя строчка кадра, NMI заканчивается на 260-й
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

    return cycles;
}
