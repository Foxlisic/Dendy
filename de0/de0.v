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

// Маппер
// --------------------------------------------------------------

wire [7:0]  x2a, x2i, x2o, oama, oamd;
wire [7:0]  chr_i, vrm_i;
wire        x2w;

// Чтение [CHR или VRAM]
wire [ 7:0] prg_in;
wire [ 7:0] ram_in;
wire [13:0] chra;
wire [15:0] prga;
wire [ 7:0] oam2a, oam2i, oam2o, vidi, vidp, prgd;
wire        oam2w, vidw, prgw, ce_cpu, nmi;
wire [14:0] vida;

// Может переключаться маппером
wire [16:0] prg_address = prga[14:0];

// Выбор источника памяти
wire        w_rom = (prgi >= 16'h8000);
wire        w_ram = (prgi <  16'h2000);
wire [ 7:0] prgi =
    w_rom ? prg_in :
    w_ram ? ram_in :
            8'hFF;

// Для видеоадаптера
wire [7:0]  chrd =
    chra < 14'h2000 ? chr_i :
    chra < 14'h3F00 ? vrm_i : 8'hFF;

// PPU Pixel Processing Unix
// --------------------------------------------------------------

ppu DendyPPU
(
    .clock25    (clock_25),
    .reset_n    (locked),
    .ce_cpu     (ce_cpu),
    .nmi        (nmi),
    // -- Физический интерфейс --
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    // -- Удвоение 2Y --
    .x2a        (x2a),
    .x2i        (x2i),
    .x2o        (x2o),
    .x2w        (x2w),
    // -- CHR-ROM --
    .chra       (chra),
    .chrd       (chrd),
    // -- OAM --
    .oama       (oama),
    .oamd       (oamd),
    .oam2a      (oam2a),
    .oam2i      (oam2i),
    .oam2o      (oam2o),
    .oam2w      (oam2w),
    // -- VIDEO --
    .vida       (vida),
    .vidi       (vidi),
    .vido       (vido),
    .vidw       (vidw),
    // -- PROGRAM --
    .prga       (prga),
    .prgi       (prgi),
    .prgd       (prgd),
    .prgw       (prgw),
);

// Подключение модулей памяти
// --------------------------------------------------------------

// 2K RAM
mem_ram DendyRAM
(
    .clock      (clock_100),
    .a          (prga[10:0]),
    .d          (prgd),
    .q          (ram_in),
    .w          (prgw && w_ram),
);

// 128K для памяти программ :: работает по мапперу
mem_prg DendyPROGRAM
(
    .clock      (clock_100),
    .a          (prg_address),
    .q          (prg_in),
);

// 64K для знакогенератора [8k x 8]
mem_chr DendyCHRROM
(
    .clock      (clock_100),
    .a          (chra[12:0]),
    .q          (chr_i),
);

// 2K для знакогенератора
mem_vrm DendyVideoRAM
(
    .clock      (clock_100),
    .a          (chra[10:0]),
    .q          (vrm_i),
    .ax         (vida[10:0]),
    .qx         (vidi),
    .dx         (vido),
    .wx         (vidw),
);

// 1K для символов спрайтов
mem_oam DendyOAM
(
    .clock      (clock_100),
    .a          (oama),
    .q          (oamd),
    .ax         (oam2a),
    .qx         (oam2i),
    .dx         (oam2o),
    .wx         (oam2w),
);

// 1K Для хранения сканлайна
mem_x2 MemoryDoubleVGA
(
    .clock      (clock_100),
    .a          (x2a),
    .q          (x2i),
    .d          (x2o),
    .w          (x2w),
);

endmodule

`include "../ppu.v"
