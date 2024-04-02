/* verilator lint_off WIDTH */
module ppu
(
    input               clock,
    input               reset_n,
    input       [15:0]  address,
    input       [ 7:0]  in,
    input               rd,
    input               we,
    output  reg         lock_cpu,       // Разрешение работы CPU
    // MEMORY
    output  reg [13:0]  ppu_addr,
    input       [ 7:0]  ppu_in,
    output reg  [ 7:0]  ppu_out,
    output reg          ppu_we,
    // VGA OUT
    output reg  [ 3:0]  R,
    output reg  [ 3:0]  G,
    output reg  [ 3:0]  B,
    output              HS,
    output              VS
);

// ---------------------------------------------------------------------
// Тайминги для горизонтальной и вертикальной развертки
//           Visible       Front        Sync        Back       Whole
parameter hzv =  640, hzf =   16, hzs =   96, hzb =   48, hzw =  800,
          vtv =  480, vtf =   10, vts =    2, vtb =   33, vtw =  525;
// ---------------------------------------------------------------------
assign HS = X  < (hzb + hzv + hzf); // NEG.
assign VS = Y  < (vtb + vtv + vtf); // NEG.
// ---------------------------------------------------------------------
// Позиция луча в кадре и максимальные позиции (x,y)
reg  [10:0] X    = 0;
reg  [ 9:0] Y    = 0;
wire        xmax = (X == hzw - 1);
wire        ymax = (Y == vtw - 1);
wire [11:0] x    = (X - hzb) - 48;  // 48=2x24; 24=16[бордер]+8[предзагрузка]
wire [10:0] y    = (Y - vtb);

// ---------------------------------------------------------------------
reg  [ 1:0] cck;
// ---------------------------------------------------------------------
wire [ 1:0] tilepage = mappage ^ x[9] ^ y[9];
reg  [ 7:0] char, attr;

// Выбранная страница
reg         chrpage; // фона в CHR-ROM
reg         mappage; // тайловой карты

// Фоновый цвет
reg  [ 3:0] bgcolor;

// Палитры фона и спрайтов
reg  [ 6:0] palbg[16];

// Номер цветового тайла 2x2
wire [ 2:0] asel = {y[5], x[5], 1'b0};

// Вычисление цвета фона
reg  [17:0] mask, mask_;

// Выбор пикселя
wire [ 1:0] maskbg = {mask[{1'b1, ~x[3:1]}], mask[{1'b0, ~x[3:1]}]};

// Область рисования Paper
wire        paper = (X >= hzb + 64) && (X < hzb + 64 + 512);

// Любой цвет, равный 0, будет использовать палитру номер 0
wire [ 3:0] bgin = {maskbg ? mask[17:16] : 2'b00, maskbg};

// Выбор итогового цвета
wire [ 5:0] cin  = palbg[ paper ? bgin : bgcolor ];
// ---------------------------------------------------------------------

// Трансляцияц цвета
wire [11:0] outcolor =
    cin == 6'h00 ?  12'h777 : cin == 6'h01 ?  12'h218 : cin == 6'h02 ?  12'h00A : cin == 6'h03 ?  12'h409 :
    cin == 6'h04 ?  12'h807 : cin == 6'h05 ?  12'hA01 : cin == 6'h06 ?  12'hA00 : cin == 6'h07 ?  12'h700 :
    cin == 6'h08 ?  12'h420 : cin == 6'h09 ?  12'h040 : cin == 6'h0A ?  12'h050 : cin == 6'h0B ?  12'h031 :
    cin == 6'h0C ?  12'h135 : cin == 6'h0D ?  12'h000 : cin == 6'h0E ?  12'h000 : cin == 6'h0F ?  12'h000 :
    cin == 6'h10 ?  12'hBBB : cin == 6'h11 ?  12'h07E : cin == 6'h12 ?  12'h23E : cin == 6'h13 ?  12'h80F :
    cin == 6'h14 ?  12'hB0B : cin == 6'h15 ?  12'hE05 : cin == 6'h16 ?  12'hD20 : cin == 6'h17 ?  12'hC40 :
    cin == 6'h18 ?  12'h870 : cin == 6'h19 ?  12'h090 : cin == 6'h1A ?  12'h0A0 : cin == 6'h1B ?  12'h093 :
    cin == 6'h1C ?  12'h088 : cin == 6'h1D ?  12'h000 : cin == 6'h1E ?  12'h000 : cin == 6'h1F ?  12'h000 :
    cin == 6'h20 ?  12'hFFF : cin == 6'h21 ?  12'h3BF : cin == 6'h22 ?  12'h59F : cin == 6'h23 ?  12'hA8F :
    cin == 6'h24 ?  12'hF7F : cin == 6'h25 ?  12'hF7B : cin == 6'h26 ?  12'hF76 : cin == 6'h27 ?  12'hF93 :
    cin == 6'h28 ?  12'hFB3 : cin == 6'h29 ?  12'h8D1 : cin == 6'h2A ?  12'h4D4 : cin == 6'h2B ?  12'h5F9 :
    cin == 6'h2C ?  12'h0ED : cin == 6'h2D ?  12'h000 : cin == 6'h2E ?  12'h000 : cin == 6'h2F ?  12'h000 :
    cin == 6'h30 ?  12'hFFF : cin == 6'h31 ?  12'hAEF : cin == 6'h32 ?  12'hCDF : cin == 6'h33 ?  12'hDCF :
    cin == 6'h34 ?  12'hFCF : cin == 6'h35 ?  12'hFCD : cin == 6'h36 ?  12'hFBB : cin == 6'h37 ?  12'hFDA :
    cin == 6'h38 ?  12'hFEA : cin == 6'h39 ?  12'hEFA : cin == 6'h3A ?  12'hAFB : cin == 6'h3B ?  12'hBFC :
    cin == 6'h3C ?  12'h9FF : cin == 6'h3D ?  12'h000 : cin == 6'h3E ?  12'h000 :                 12'h000;

always @(negedge clock)
if (reset_n == 1'b0) begin

    cck         <= 1'b0;
    ppu_we      <= 1'b0;
    chrpage     <= 1'b1;
    mappage     <= 1'b0;
    lock_cpu    <= 1'b0;

    X <= 0;
    Y <= 0;

    palbg[0]    <= 6'h0F;
    palbg[1]    <= 6'h20;
    palbg[2]    <= 6'h10;
    palbg[3]    <= 6'h00;

    // palbg[4]  <= 6'h0F;
    palbg[5]    <= 6'h1A;
    palbg[6]    <= 6'h27;
    palbg[7]    <= 6'h07;

    // palbg[8]  <= 6'h0F;
    palbg[9]    <= 6'h27;
    palbg[10]   <= 6'h17;
    palbg[11]   <= 6'h07;

    // palbg[12] <= 6'h0F;
    palbg[13]   <= 6'h20;
    palbg[14]   <= 6'h10;
    palbg[15]   <= 6'h21;

end
else begin

    // Черный цвет за пределами видимой области рисования
    {R, G, B} <= 12'h000;

    // Кадровая развертка
    X <= xmax ?         0 : X + 1;
    Y <= xmax ? (ymax ? 0 : Y + 1) : Y;

    // Процессы выполняются в замедлении до 89080Т за кадр (5.34 Mhz)
    if ({X[0], Y[0]} == 2'b00 && X < 680 && Y < 524) begin

        lock_cpu <= (cck == 1'b0);
        cck <= (cck == 2) ? 0 : cck + 1;

    end else lock_cpu <= 1'b0;

    // Вычисление видеоданных для фона
    // ----------------------------
    case (x[3:0])
    // CHAR YYYYYXXXXX
    0: begin ppu_addr <= {2'b10, tilepage, y[8:4], x[8:4]}; end
    // ATTR 1111YYYXXX
    1: begin ppu_addr <= {2'b10, tilepage, 4'b1111, y[8:6], x[8:6]}; char <= ppu_in; end
    // CHR-ROM Читать BG
    2: begin ppu_addr <= {chrpage, char, 1'b0, y[3:1]}; mask_[17:16] <= {ppu_in[asel | 1'b1], ppu_in[asel]}; end
    3: begin mask_[ 7:0] <= ppu_in; ppu_addr[3] <= 1'b1; end
    4: begin mask_[15:8] <= ppu_in; end
    // OUTPUT COLOR
    15: begin mask <= mask_; end
    endcase

    // Вывод окна видеоадаптера
    if (X >= hzb && X < hzb + hzv && Y >= vtb && Y < vtb + vtv) {R, G, B} <= outcolor;

end

endmodule
