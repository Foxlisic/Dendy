module ppu
(
    input               clock,
    input               reset_n,
    input       [15:0]  address,
    input       [ 7:0]  in,
    input               rd,
    input               we,
    output              lock_cpu,       // Разрешение работы CPU
    // MEMORY
    output  reg [10:0]  addr_ram,       // VRAM 2K
    output  reg [12:0]  addr_chr,       // CHR-ROM 8K
    input       [ 7:0]  in_ram,
    input       [ 7:0]  in_chr,
    // VGA OUT
    output      [ 3:0]  R,
    output      [ 3:0]  G,
    output      [ 3:0]  B,
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
reg  [10:0] X = 0;
reg  [ 9:0] Y = 0;
wire        xmax = (X == hzw - 1);
wire        ymax = (Y == vtw - 1);
wire [10:0] x    = (X - hzb); // x=[0..639]
wire [ 9:0] y    = (Y - vtb); // y=[0..524]
// ---------------------------------------------------------------------

always @(posedge clock) begin

    // Черный цвет за пределами видимой области рисования
    {R, G, B} <= 12'h000;

    // Кадровая развертка
    X <= xmax ?         0 : X + 1;
    Y <= xmax ? (ymax ? 0 : Y + 1) : Y;

    // Вывод окна видеоадаптера
    if (X >= hzb && X < hzb + hzv && Y >= vtb && Y < vtb + vtv) {R, G, B} <= x[3:0] == 0 || y[3:0] == 0 ? 12'hFFF : {x[4]^y[4], 3'h0, x[5]^y[5], 3'h0, x[6]^y[6], 3'h0};

end

endmodule
