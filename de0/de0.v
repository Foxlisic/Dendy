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

// TEST
assign LEDR[7:0] = out;

// Генератор частот
// --------------------------------------------------------------

wire locked;
wire clock_25;

pll PLL0
(
    .clkin     (CLOCK_50),
    .m25       (clock_25),
    .m50       (clock_50),
    .m100      (clock_100),
    .locked    (locked)
);

// Процессор
// -----------------------------------------------------------------------------

wire [15:0] address;
wire [ 7:0] out, in_ram, in_rom;
wire        irq, we, rd;

nes CPU6502
(
    .clock      (clock_25),
    .reset_n    (locked),
    .locked     (1'b1),
    .address    (address),
    .irq        (irq),
    .in         (in),
    .out        (out),
    .we         (we),
    .rd         (rd)
);

// Модули памяти
// -----------------------------------------------------------------------------

wire is_ram = (address <  16'h2000),
     is_rom = (address >= 16'h8000);

wire [ 7:0] in =
    is_ram ? in_ram :
    is_rom ? in_rom : 8'hFF;

// 1KB RAM
mem_ram M1
(
    .clock  (clock_100),
    .a      (address[9:0]),
    .w      (we & is_ram),
    .d      (out),
    .q      (in_ram)
);

// 2KB RAM
mem_rom M2
(
    .clock  (clock_100),
    .a      (address[10:0]),
    .q      (in_rom)
);

endmodule

`include "../nes.v"
