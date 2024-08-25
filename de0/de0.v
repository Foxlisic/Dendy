module de0
(
    // Reset
    input              RESET_N,

    // Clocks
    input              CLOCK_50,
    input              CLOCK2_50,
    input              CLOCK3_50,
    input              CLOCK4_50,

    // DRAM
    output             DRAM_CKE,
    output             DRAM_CLK,
    output      [1:0]  DRAM_BA,
    output      [12:0] DRAM_ADDR,
    inout       [15:0] DRAM_DQ,
    output             DRAM_CAS_N,
    output             DRAM_RAS_N,
    output             DRAM_WE_N,
    output             DRAM_CS_N,
    output             DRAM_LDQM,
    output             DRAM_UDQM,

    // GPIO
    inout       [35:0] GPIO_0,
    inout       [35:0] GPIO_1,

    // 7-Segment LED
    output      [6:0]  HEX0,
    output      [6:0]  HEX1,
    output      [6:0]  HEX2,
    output      [6:0]  HEX3,
    output      [6:0]  HEX4,
    output      [6:0]  HEX5,

    // Keys
    input       [3:0]  KEY,

    // LED
    output      [9:0]  LEDR,

    // PS/2
    inout              PS2_CLK,
    inout              PS2_DAT,
    inout              PS2_CLK2,
    inout              PS2_DAT2,

    // SD-Card
    output             SD_CLK,
    inout              SD_CMD,
    inout       [3:0]  SD_DATA,

    // Switch
    input       [9:0]  SW,

    // VGA
    output      [3:0]  VGA_R,
    output      [3:0]  VGA_G,
    output      [3:0]  VGA_B,
    output             VGA_HS,
    output             VGA_VS
);

// MISO: Input Port
assign SD_DATA[0] = 1'bZ;

// SDRAM Enable
assign DRAM_CKE  = 1;   // ChipEnable
assign DRAM_CS_N = 0;   // ChipSelect

// Z-state
assign DRAM_DQ = 16'hzzzz;
assign GPIO_0  = 36'hzzzzzzzz;
assign GPIO_1  = 36'hzzzzzzzz;

// LED OFF
assign HEX0 = 7'b1111111;
assign HEX1 = 7'b1111111;
assign HEX2 = 7'b1111111;
assign HEX3 = 7'b1111111;
assign HEX4 = 7'b1111111;
assign HEX5 = 7'b1111111;

// Провода
// --------------------------------------------------------------
wire [7:0]  x2a, x2i, x2o, chrd, oama, oamd;
wire [7:0]  chr_i, vram_i;
wire        x2w;

// Чтение [CHR или VRAM]
wire [13:0] chra;
wire [7:0]  chrd = chra < 14'h2000 ? chr_i : (chra < 14'h3F00 ? vram_i : 8'hFF);

// Генератор частот
// --------------------------------------------------------------

wire locked;
wire clock_25;

pll PLL0
(
    .clkin      (CLOCK_50),
    .m25        (clock_25),
    .m50        (clock_50),
    .m100       (clock_100),
    .locked     (locked)
);

// PPU Pixel Processing Unix
// --------------------------------------------------------------

ppu DendyPPU
(
    .clock25    (clock_25),
    .reset_n    (locked),
    // -- Физический интерфейс --
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    // -- Подключение к памяти --
    .x2a        (x2a),
    .x2i        (x2i),
    .x2o        (x2o),
    .x2w        (x2w),
    .oama       (oama),
    .oamd       (oamd),
    .chra       (chra),
    .chrd       (chrd),
);

// Подключение модулей памяти
// --------------------------------------------------------------

// Для хранения сканлайна
mem_x2 MemoryDoubleVGA
(
    .clock      (clock_100),
    .a          (x2a),
    .q          (x2i),
    .d          (x2o),
    .w          (x2w),
);

// 8K для знакогенератора
mem_chr DendyCHRROM
(
    .clock      (clock_100),
    .a          (chra[12:0]),
    .q          (chr_i),
);

// 2K для знакогенератора
mem_vram DendyVideoRAM
(
    .clock      (clock_100),
    .a          (chra[10:0]),
    .q          (vram_i),
);

// 1K для символов спрайтов
mem_oam DendyVideoRAM
(
    .clock      (clock_100),
    .a          (oama),
    .q          (oamd),
);

endmodule

`include "../ppu.v"
