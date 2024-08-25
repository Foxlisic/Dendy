/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

/**
 * Формирование видеосигнала на VGA 800 x 525
 * Однако, работают по таймингам 341 x 262
 */

module ppu
(
    input               clock25,
    input               reset_n,
    // --- Интерфейс видеосигнала ---
    output      [3:0]   r,
    output      [3:0]   g,
    output      [3:0]   b,
    output              hs,
    output              vs,
    // --- Процессор ---
    input       [15:0]  cpu_a,      // Адрес
    output      [ 7:0]  cpu_i,      // Данные чтения
    input       [ 7:0]  cpu_o,      // Данные записи
    input               cpu_w,      // Сигнал записи
    input               cpu_r,      // Сигнал чтения
    // --- Счетчики ---
    output reg  [8:0]   px,         // PPU.x = 0..340
    output reg  [8:0]   py,         // PPU.y = 0..261
    // --- Видеопамять ---
    output reg  [15:0]  chra,       // Адрес в видеопамяти
    input       [ 7:0]  chrd,       // Данные из видеопамяти
    // --- OAM ---
    output reg  [ 7:0]  oama,
    input       [ 7:0]  oamd,
    // --- Удвоение сканлайна ---
    output reg  [ 7:0]  x2a,
    input       [ 7:0]  x2i,
    output reg  [ 7:0]  x2o,
    output reg          x2w,
    // --- Управление ---
    output reg          ce_cpu,
    output reg          ce_ppu
);

assign {r, g, b} =

    cl == 6'h00 ? 12'h777 : cl == 6'h01 ? 12'h218 : cl == 6'h02 ? 12'h00A : cl == 6'h03 ? 12'h409 :
    cl == 6'h04 ? 12'h807 : cl == 6'h05 ? 12'hA01 : cl == 6'h06 ? 12'hA00 : cl == 6'h07 ? 12'h700 :
    cl == 6'h08 ? 12'h420 : cl == 6'h09 ? 12'h040 : cl == 6'h0A ? 12'h050 : cl == 6'h0B ? 12'h031 :
    cl == 6'h0C ? 12'h135 : cl == 6'h0D ? 12'h000 : cl == 6'h0E ? 12'h000 : cl == 6'h0F ? 12'h000 :
    // --
    cl == 6'h10 ? 12'hBBB : cl == 6'h11 ? 12'h07E : cl == 6'h12 ? 12'h23E : cl == 6'h13 ? 12'h80F :
    cl == 6'h14 ? 12'hB0B : cl == 6'h15 ? 12'hE05 : cl == 6'h16 ? 12'hD20 : cl == 6'h17 ? 12'hC40 :
    cl == 6'h18 ? 12'h870 : cl == 6'h19 ? 12'h090 : cl == 6'h1A ? 12'h0A0 : cl == 6'h1B ? 12'h093 :
    cl == 6'h1C ? 12'h088 : cl == 6'h1D ? 12'h000 : cl == 6'h1E ? 12'h000 : cl == 6'h1F ? 12'h000 :
    // --
    cl == 6'h20 ? 12'hFFF : cl == 6'h21 ? 12'h3BF : cl == 6'h22 ? 12'h59F : cl == 6'h23 ? 12'hA8F :
    cl == 6'h24 ? 12'hF7F : cl == 6'h25 ? 12'hF7B : cl == 6'h26 ? 12'hF76 : cl == 6'h27 ? 12'hF93 :
    cl == 6'h28 ? 12'hFB3 : cl == 6'h29 ? 12'h8D1 : cl == 6'h2A ? 12'h4D4 : cl == 6'h2B ? 12'h5F9 :
    cl == 6'h2C ? 12'h0ED : cl == 6'h2D ? 12'h000 : cl == 6'h2E ? 12'h000 : cl == 6'h2F ? 12'h000 :
    // --
    cl == 6'h30 ? 12'hFFF : cl == 6'h31 ? 12'hAEF : cl == 6'h32 ? 12'hCDF : cl == 6'h33 ? 12'hDCF :
    cl == 6'h34 ? 12'hFCF : cl == 6'h35 ? 12'hFCD : cl == 6'h36 ? 12'hFBB : cl == 6'h37 ? 12'hFDA :
    cl == 6'h38 ? 12'hFEA : cl == 6'h39 ? 12'hEFA : cl == 6'h3A ? 12'hAFB : cl == 6'h3B ? 12'hBFC :
    cl == 6'h3C ? 12'h9FF :                                                               12'h000;

// ---------------------------------------------------------------------
// Тайминги для горизонтальной и вертикальной развертки
//           Visible       Front        Sync        Back       Whole
parameter hzv =  640, hzf =   16, hzs =   96, hzb =   48, hzw =  800,
          vtv =  480, vtf =   10, vts =    2, vtb =   33, vtw =  525;

// Вычисления границ кадра или линии
// ---------------------------------------------------------------------
assign  hs      = x  < (hzb + hzv + hzf); // NEG.
assign  vs      = y  < (vtb + vtv + vtf); // NEG.
wire    xmax    = (x == hzw - 1);
wire    ymax    = (y == vtw - 1);
wire    vsx     = x >= hzb && x < hzb+640;
wire    vsy     = y >= vtb && y < vtb+480;
wire    border  = vsx && vsy && (x < hzb + 64 || x > hzb + 64 + 512);
wire    paper   = px >= 32 && px < (32 + 256) && py >= 16 && py < 256;

// Позиция луча в кадре и максимальные позиции (x,y)
// ---------------------------------------------------------------------
reg  [ 9:0] x = 0;
reg  [ 9:0] y = 0;
reg  [14:0] v = 0, t = 0;
reg  [ 1:0] ct_cpu = 0;
reg  [ 2:0] finex = 0, _finex = 0;
reg  [ 7:0] ctrl0;              // $2000
reg  [ 7:0] ctrl1;              // $2001
reg  [15:0] bgtile, _bgtile;    // Сохраненное значение тайла фона
reg  [ 1:0] bgattr;             // Номер палитры для фона (0..2)
reg  [ 5:0] cl = 6'h00;
reg  [ 5:0] bgpal[16];          // Палитра фона
reg  [ 5:0] sppal[16];          // Палитра спрайтов
// ---------------------------------------------------------------------
reg  [31:0] sp[8];
reg  [ 7:0] oam_y;              // Временное Y
reg  [ 3:0] oam_st;
reg  [ 3:0] oam_ln;             // Отступ от верха спрайта
reg  [ 3:0] oam_id;             // oam_id[3] == Overflow
reg         oam_hit;
reg         sp_invx;            // Инверсия по X спрайта
// ---------------------------------------------------------------------
wire [ 4:0] coarse_x    = v[4:0],
            coarse_y    = v[9:5];
wire [ 2:0] fine_y      = v[14:12];
wire [ 7:0] rx          = px - 32,
            ry          = py - (16 + 1);        // +1 Из-за пропуска линии
wire [ 3:0] sp_height   = (ctrl0[5] ? 16 : 8);
wire [ 7:0] sp_chrd     = sp_invx ? {chrd[0],chrd[1],chrd[2],chrd[3],chrd[4],chrd[5],chrd[6],chrd[7]} : chrd;

// Вычисление цвета
// ---------------------------------------------------------------------

// Расчет отступов
wire [2:0]
    sp0_x  = sp[0][31:24] - rx, sp1_x  = sp[1][31:24] - rx,
    sp2_x  = sp[2][31:24] - rx, sp3_x  = sp[3][31:24] - rx,
    sp4_x  = sp[4][31:24] - rx, sp5_x  = sp[5][31:24] - rx,
    sp6_x  = sp[6][31:24] - rx, sp7_x  = sp[7][31:24] - rx;

// Попадание в диапазон [1..8] Пиксель PX запаздывает на +1
wire
    sp0_b  = rx > sp[0][31:24] && rx <= sp[0][31:24] + 8,
    sp1_b  = rx > sp[1][31:24] && rx <= sp[1][31:24] + 8,
    sp2_b  = rx > sp[2][31:24] && rx <= sp[2][31:24] + 8,
    sp3_b  = rx > sp[3][31:24] && rx <= sp[3][31:24] + 8,
    sp4_b  = rx > sp[4][31:24] && rx <= sp[4][31:24] + 8,
    sp5_b  = rx > sp[5][31:24] && rx <= sp[5][31:24] + 8,
    sp6_b  = rx > sp[6][31:24] && rx <= sp[6][31:24] + 8,
    sp7_b  = rx > sp[7][31:24] && rx <= sp[7][31:24] + 8;

// Цвет пикселя
wire [4:0]
    sp0_i  = {1'b1, sp[0][17:16], sp[0][8 + sp0_x], sp[0][sp0_x]},
    sp1_i  = {1'b1, sp[1][17:16], sp[1][8 + sp1_x], sp[1][sp1_x]},
    sp2_i  = {1'b1, sp[2][17:16], sp[2][8 + sp2_x], sp[2][sp2_x]},
    sp3_i  = {1'b1, sp[3][17:16], sp[3][8 + sp3_x], sp[3][sp3_x]},
    sp4_i  = {1'b1, sp[4][17:16], sp[4][8 + sp4_x], sp[4][sp4_x]},
    sp5_i  = {1'b1, sp[5][17:16], sp[5][8 + sp5_x], sp[5][sp5_x]},
    sp6_i  = {1'b1, sp[6][17:16], sp[6][8 + sp6_x], sp[6][sp6_x]},
    sp7_i  = {1'b1, sp[7][17:16], sp[7][8 + sp7_x], sp[7][sp7_x]};

// Спрайт перед фоном (=0) или за фоном (=1)
wire
    sp0_u = (!sp[0][21] || {sp[0][21], back_b[1:0]} == 3'b100),
    sp1_u = (!sp[1][21] || {sp[1][21], pipe_0[1:0]} == 3'b100),
    sp2_u = (!sp[2][21] || {sp[2][21], pipe_1[1:0]} == 3'b100),
    sp3_u = (!sp[3][21] || {sp[3][21], pipe_2[1:0]} == 3'b100),
    sp4_u = (!sp[4][21] || {sp[4][21], pipe_3[1:0]} == 3'b100),
    sp5_u = (!sp[5][21] || {sp[5][21], pipe_4[1:0]} == 3'b100),
    sp6_u = (!sp[6][21] || {sp[6][21], pipe_5[1:0]} == 3'b100),
    sp7_u = (!sp[7][21] || {sp[7][21], pipe_6[1:0]} == 3'b100);

// -- Слой 0: Задний план
wire [1:0]  back_a = {bgtile[{1'b1, ~finex}], bgtile[{1'b0, ~finex}]};
wire [4:0]  back_b = back_a ? {bgattr[1:0], back_a} : 5'b0;

// -- Слой 1: Спрайты
wire [4:0]  pipe_0 = (oam_id >= 1 && sp0_b && sp0_u && sp0_i[1:0]) ? sp0_i : back_b;
wire [4:0]  pipe_1 = (oam_id >= 2 && sp1_b && sp1_u && sp1_i[1:0]) ? sp1_i : pipe_0;
wire [4:0]  pipe_2 = (oam_id >= 3 && sp2_b && sp2_u && sp2_i[1:0]) ? sp2_i : pipe_1;
wire [4:0]  pipe_3 = (oam_id >= 4 && sp3_b && sp3_u && sp3_i[1:0]) ? sp3_i : pipe_2;
wire [4:0]  pipe_4 = (oam_id >= 5 && sp4_b && sp4_u && sp4_i[1:0]) ? sp4_i : pipe_3;
wire [4:0]  pipe_5 = (oam_id >= 6 && sp5_b && sp5_u && sp5_i[1:0]) ? sp5_i : pipe_4;
wire [4:0]  pipe_6 = (oam_id >= 7 && sp6_b && sp6_u && sp6_i[1:0]) ? sp6_i : pipe_5;
wire [4:0]  pipe_7 = (oam_id >= 8 && sp7_b && sp7_u && sp7_i[1:0]) ? sp7_i : pipe_6;

//-- Слой 2: Итоговый цвет
wire [5:0]  dst    = pipe_7[4] ? sppal[pipe_7[3:0]] : bgpal[pipe_7[3:0]];

// Процессор
// ---------------------------------------------------------------------

always @(posedge clock25)
if (reset_n == 1'b0)
begin

    x           <= 0;
    y           <= 0;       // 0|1
    px          <= 0;
    py          <= 0;       // 0|16
    finex       <= 0;
    ce_cpu      <= 0;
    ce_ppu      <= 0;
    ct_cpu      <= 0;

    oama        <= 0;
    oam_st      <= 0;
    oam_id      <= 0;

    //               FnY VH CoarY CoarX
    v       <= 16'b0_000_00_00000_00000;
    t       <= 16'b0_000_00_00000_00000;

    //               4
    ctrl0   <= 8'b0001_0000;
    ctrl1   <= 8'b0000_0000;

    // Палитра фона
    bgpal[ 0] <= 6'h0F; bgpal[ 1] <= 6'h16; bgpal[ 2] <= 6'h30; bgpal[ 3] <= 6'h38;
    bgpal[ 4] <= 6'h00; bgpal[ 5] <= 6'h16; bgpal[ 6] <= 6'h26; bgpal[ 7] <= 6'h07;
    bgpal[ 8] <= 6'h00; bgpal[ 9] <= 6'h26; bgpal[10] <= 6'h00; bgpal[11] <= 6'h30;
    bgpal[12] <= 6'h00; bgpal[13] <= 6'h38; bgpal[14] <= 6'h28; bgpal[15] <= 6'h10;

    // Палитра фона
    sppal[ 0] <= 6'h0F; sppal[ 1] <= 6'h16; sppal[ 2] <= 6'h27; sppal[ 3] <= 6'h12;
    sppal[ 4] <= 6'h0F; sppal[ 5] <= 6'h30; sppal[ 6] <= 6'h2B; sppal[ 7] <= 6'h16;
    sppal[ 8] <= 6'h0F; sppal[ 9] <= 6'h39; sppal[10] <= 6'h28; sppal[11] <= 6'h27;
    sppal[12] <= 6'h0F; sppal[13] <= 6'h30; sppal[14] <= 6'h30; sppal[15] <= 6'h30;

end
else
begin

    // Разрешение такта для CPU
    ce_cpu <= 0;
    ce_ppu <= 0;
    x2w    <= 0;

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // -----------------------------------------------------

    // Области гашения луча :: черный цвет
    if (!vsy || !vsx) begin cl <= 6'h3F; end
    // Фоновый цвет
    else if (border) cl <= bgpal[0];

    // -----------------------------------------------------

    // На 524-й строке обнулить счетчики PX,PY
    if      (ymax) begin px <= 0; py <= 0; end
    else if (xmax) begin px <= 0; end
    // 1x1 PPU = 2x2 VGA [HZB ... +2*341)
    // Процессинг PPU, чересстрочный для VGA
    else if (x >= hzb && x < hzb + 341*2) begin

        // Обработчик спрайтов и удвоение линии [четная линия x0]
        // ---------------------------------------------------------
        if (y[0] == 0 && py >= 16)
        begin

            // 2x по высоте
            if (!border && py <= 256)
            begin

                if (x[0]) cl  <= x2i;
                else      x2a <= ((x - hzb) >> 1) - 32;

            end

            case (oam_st)

            // Процессинг спрайтов
            0: begin

                oam_st  <= 1;
                oama    <= 0;
                oam_id  <= 0;

            end

            // Проверка попадания в Y
            1: begin

                // Спрайт подходит под выборку: читать атрибуты
                if (oamd <= ry && ry < oamd + sp_height) begin

                    oam_st <= 2;
                    oama   <= oama + 2;
                    oam_y  <= oamd;

                end
                // Если не конец OAM, повторить чтение
                else begin

                    oam_st <= oama == 252 ? 8 : 1;
                    oama   <= oama + 4;

                end

            end

            // Читать атрибуты
            2: begin

                oam_st  <= 3;
                oama    <= oama - 1;
                oam_ln  <= oamd[7] ? sp_height - 1 - ry + oam_y : ry - oam_y;
                sp_invx <= oamd[6];

                // 23 Отражение горизонт  =0 Нет =1 Да
                // 22 Отражение горизонт  =0 Нет =1 Да
                // 21 Приоритет =1 Перед фоном =0 За фоном
                // 17:16 Палитра

                sp[oam_id][23:16] <= oamd;

            end

            // Читать номер знакогенератора
            // Если спрайты 8x16 => младший бит номера спрайта выбирает CHR-ROM [0/1]
            // Старшие 7 бит выбирают номер тайла 0, 2, 4 и т.д.
            3: begin

                oam_st <= 4;
                oama   <= oama + 2;

                if (ctrl0[5])
                    chra <= {oamd[0],  oamd[7:1], oam_ln[3], 1'b0, oam_ln[2:0]};
                else      // 12        11                 4     3  2..0
                    chra <= {ctrl0[3], oamd[7:1],   oamd[0], 1'b0, oam_ln[2:0]};

            end

            // Читать младший байт
            4: begin

                oam_st  <= 5;
                oama    <= oama + 1;
                chra[3] <= 1'b1;

                sp[oam_id][  7:0] <= sp_chrd;  // BGBot
                sp[oam_id][31:24] <= oamd;     // X

            end

            // К следующему спрайту
            // Читать старшую часть байта
            // Если считывается OAM_ID=0 и хотя бы какой-то бит не 0 =>
            // То этот спрайт является ZeroHit на линии, потому что он виден
            5: begin

                oam_id   <= oam_id + 1;
                oam_st   <= oam_id == 7 ? 8 : 1;
                oam_hit  <= oam_id == 0 && sp[0][15:0];

                sp[oam_id][ 15:8] <= sp_chrd; // BGTop

            end

            // Ожидание конца линии
            // После этого будет переключено на нечетную линию.
            // Все собранные данные сохраняться на ее протяжении
            8: begin if (x == hzb + 341*2 - 1) oam_st <= 0; end

            endcase

        end

        // Пиксельный процессор [нечетная линия 01]
        // ---------------------------------------------------------
        if (x[0] & y[0])
        begin

            // 3Т PPU = 1T CPU
            ct_cpu <= (ct_cpu == 2) ? 0 : ct_cpu + 1;
            ce_cpu <= (ct_cpu == 0);
            ce_ppu <= 1;

            // Формирование фоновой картинки
            // ---------------------------------------------------------
            // 8 пиксельный пре-рендер данных
            if (px >= 32-8 && px < 32+256)
            begin

                // При любом кратном 8x вернется на исходную позицию
                finex <= finex + 1;

                case (finex)
                // Запрос символа [2Bit Nametable, 5Bit Coarse Y, 5Bit Coarse X]
                3: begin chra <= {4'h2, /*NT*/ v[11:10], coarse_y, coarse_x}; end
                // Чтение символа и запрос знакогенератора [NT 1 + CHR 8 + 1CLR + FineY 3]
                4: begin chra <= {ctrl0[4], chrd[7:0], 1'b0, fine_y}; end
                // Чтение знакогенератора [2 байта]
                5: begin _bgtile[ 7:0] <= chrd; chra[3] <= 1'b1; end
                // Запрос атрибутов
                6: begin

                    chra <= {4'h2, /*NT*/ v[11:10], /* X=0, Y=30 */ 4'b1111, coarse_y[4:2], coarse_x[4:2]};
                    _bgtile[15:8] <= chrd;

                end

                // Чтение атрибута, инкременты
                7: begin

                    // Данные на выход
                    bgattr[0] <= chrd[{v[6],v[1],1'b0}];
                    bgattr[1] <= chrd[{v[6],v[1],1'b1}];
                    bgtile    <= _bgtile;

                    // X++ :: Смена NT[Horiz]
                    v[10]  <= (v[4:0] == 31) ? ~v[10] : v[10];
                    v[4:0] <= (v[4:0] + 1);

                end
                endcase

            end

            // Переход к следующей линии
            if (px == 32+256+4)
            begin

                // Вернуть горизонтальным счетчикам значение из `t` для рисования новой строки [horiz]
                {v[10], v[4:0]} <= {t[10], t[4:0]};

                // Инкремент CoarseY
                if (fine_y == 7)
                begin

                    // Смена NT[Vertical]
                    if      (v[9:5] == 29) begin v[9:5] <= 0; v[11] <= ~v[11]; end
                    // Сброс Y на 31-й строке
                    else if (v[9:5] == 31) begin v[9:5] <= 0; end
                    // CoarseY++
                    else                   begin v[9:5] <= v[9:5] + 1; end

                end

                // FineY++
                v[14:12] <= fine_y + 1;

            end

            // Кадр начинается с позиции PY=15, так как 33 пикселя сверху идут для VGA как VBlank
            // Вернуть вертикальным счетчикам  значение из `t` для рисования нового кадра [vert]
            if (px == 32+256+8 && py == 15) begin

                {v[14:12], v[11], v[9:5]} <= {t[14:12], t[11], t[9:5]};

                oam_hit <= 0;

            end

            // Счетчик PX, PY
            px <= (px == 340) ? 0 : px + 1;
            py <= (px == 340) ? py + 1 : py;

            // Видимая область [pX=32..287, PY=16..255]
            if (paper) begin

                cl  <= dst;
                x2o <= dst;
                x2a <= px - 32;
                x2w <= 1;

            end

        end

    end

end

endmodule
