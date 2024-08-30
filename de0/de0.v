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

// Джойстик сега
// --------------------------------------------------------------

wire [11:0] joy1;
wire [11:0] joy2;

joy SegaJoy1
(
    .clock      (clock_25),
    .pin_d1     (~GPIO_1[29]),
    .pin_d2     (~GPIO_1[28]),
    .pin_d3     (~GPIO_1[26]),
    .pin_d4     (~GPIO_1[27]),
    .pin_d6     (~GPIO_1[24]),
    .pin_d9     (~GPIO_1[25]),
    .pin_d7     ( GPIO_1[22]),
    .joy        (joy1)
);

// Маппер
// --------------------------------------------------------------

wire        prg_size = SW[0];       // 0=16K 1=32K
wire [2:0]  chr_bank = SW[3:1];     // 8 Номер CHR-TABLE
wire [2:0]  prg_bank = SW[6:4];     // 8 Смещение PRG-TABLE [16K]

wire        reset_n = RESET_N & locked;
wire [7:0]  x2a, x2i, x2o, oama, oamd;
wire [7:0]  chr_i, vrm_i;
wire        x2w;

// Чтение [CHR или VRAM]
wire [ 7:0] prg_in;
wire [ 7:0] ram_in;
wire [14:0] chra;
wire [15:0] prga;
wire [14:0] vida;
wire [ 7:0] oam2a, oam2i, oam2o, vidi, vido, prgd;
wire        oam2w, vidw, prgw;

// CPU
wire [15:0] cpu_a;
wire [ 7:0] cpu_i, cpu_o;
wire        ce_cpu, nmi, cpu_w, cpu_r;

// Переключается маппером [prg_bank]
wire [16:0] prg_address = (prg_bank << 14) + (prg_size ? prga[14:0] : prga[13:0]);

// Выбор источника памяти
wire        w_rom = (prga >= 16'h8000);
wire        w_ram = (prga <  16'h2000);

// Либо чтение RAM, либо ROM
wire [ 7:0] prgi = w_rom ? prg_in : (w_ram ? ram_in : 8'hFF);

// Чтение CHR-ROM или CHR-RAM
wire [7:0]  chrd = chra < 14'h2000 ? chr_i : (chra < 14'h3F00 ? vrm_i : 8'hFF);

// CPU Central Processing Unix
// ---------------------------------------------------------------------

cpu DendyCPU
(
    .clock      (clock_25),
    .reset_n    (reset_n),
    .ce         (ce_cpu),
    .nmi        (nmi),
    .A          (cpu_a),
    .I          (cpu_i),
    .D          (cpu_o),
    .R          (cpu_r),
    .W          (cpu_w),
);

// PPU Pixel Processing Unix
// ---------------------------------------------------------------------

ppu DendyPPU
(
    .clock25    (clock_25),
    .reset_n    (reset_n),
    .ce_cpu     (ce_cpu),
    .nmi        (nmi),
    // -- VGA --
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    // --- Процессор ---
    .cpu_a      (cpu_a),
    .cpu_i      (cpu_i),
    .cpu_o      (cpu_o),
    .cpu_r      (cpu_r),
    .cpu_w      (cpu_w),
    // --- Джойстики ---
    .joy1       (joy1[7:0]),
    .joy2       (joy2[7:0]),
    // -- PROGRAM --
    .prga       (prga),
    .prgi       (prgi),
    .prgd       (prgd),
    .prgw       (prgw),
    // -- VIDEO --
    .vida       (vida),
    .vidi       (vidi),
    .vido       (vido),
    .vidw       (vidw),
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
    // -- Удвоение 2Y --
    .x2a        (x2a),
    .x2i        (x2i),
    .x2o        (x2o),
    .x2w        (x2w),
);

// Программная память, переключаемая маппером
// ---------------------------------------------------------------------

// 128K для памяти программ :: работает по мапперу
mem_prg DendyPROGRAM
(
    .clock      (clock_100),
    .a          (prg_address),
    .q          (prg_in),
);

// 8K для знакогенератора
mem_chr DendyCHRROM
(
    .clock      (clock_100),
    .a          ({chr_bank, chra[12:0]}), // 15 14 13] 12
    .q          (chr_i),
);

// Подключение модулей памяти
// ---------------------------------------------------------------------

// 2K RAM
mem_ram DendyRAM
(
    .clock      (clock_100),
    .a          (prga[10:0]),
    .d          (prgd),
    .q          (ram_in),
    .w          (prgw & w_ram),
);

// 2K для Name Tables
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

// ---------------------------------------------------------------------

`include "../cpu.v"
`include "../ppu.v"
