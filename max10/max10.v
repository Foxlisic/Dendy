module max10
(
    output wire [13:0] IO,
    output wire [ 3:0] LED,
    input  wire [ 1:0] KEY,
    input  wire        SERIAL_RX,
    output wire        SERIAL_TX,
    input  wire        CLK100MHZ
);

assign IO[4:0] = {vga_r[3], vga_g[3], vga_b[3], vga_hs, vga_vs};
assign IO[12:5] = out;

// Генерация частот
// -----------------------------------------------------------------------------
wire locked;
wire clock_25;

pll unit_pll
(
    .clk       (CLK100MHZ),
    .m25       (clock_25),
    .m100      (clock_100),
    .locked    (locked)
);

// Процессор
// -----------------------------------------------------------------------------

wire [15:0] address;
wire [ 7:0] out, in_ram, in_rom;
wire        irq, we, rd;
wire        lock_cpu;

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

// Видеопроцессор
// -----------------------------------------------------------------------------

wire [13:0] ppu_addr;
wire [ 7:0] ppu_out;
wire        ppu_we;
wire [ 3:0] vga_r, vga_g, vga_b;
wire        vga_hs, vga_vs;

// Роутер PPU памяти
wire [ 7:0] ppu_in =
    is_chr  ? ppu_in_chr :
    is_vram ? ppu_in_vram : 8'hFF;

ppu PPU
(
    .clock      (clock_25),
    .reset_n    (locked),
    .address    (address),
    .in         (in),
    .rd         (rd),
    .we         (we),
    .lock_cpu   (lock_cpu),
    // MEMORY
    .ppu_addr   (ppu_addr),
    .ppu_in     (ppu_in),
    .ppu_out    (ppu_out),
    .ppu_we     (ppu_we),
    // VGA OUT
    .R          (vga_r),
    .G          (vga_g),
    .B          (vga_b),
    .HS         (vga_hs),
    .VS         (vga_vs)
);

// Модули памяти
// 2K RAM;  4K PRG-ROM Ограниченная память PRG
// 2K VRAM; 4K PRG-ROM Спрайты не поддерживаются, 2 окна
// -----------------------------------------------------------------------------
wire [7:0] ppu_in_vram, ppu_in_chr;

wire is_ram  = (address <  16'h2000),
     is_rom  = (address >= 16'h8000),
     is_chr  = ppu_addr[13]    == 1'b0,
     is_vram = ppu_addr[13:12] == 2'b10;

wire [ 7:0] in =
    is_ram ? in_ram :
    is_rom ? in_rom : 8'hFF;

// Процессор ---

// 2KB RAM
mem_ram M1
(
    .clock      (clock_100),
    .address_a  (address[10:0]),
    .wren_a     (we & is_ram),
    .data_a     (out),
    .q_a        (in_ram)
);

// 4KB ROM
mem_rom M2
(
    .clock      (clock_100),
    .address_a  (address[11:0]),
    .q_a        (in_rom)
);

// Видео ---

// 4KB CHR-ROM
mem_chr M3
(
    .clock      (clock_100),
    .address_a  (ppu_addr[11:0]),
    .q_a        (ppu_in_chr)
);

// 2KB VRAM
mem_vram M4
(
    .clock      (clock_100),
    .address_a  (ppu_addr[10:0]),
    .wren_a     (ppu_we & is_vram),
    .data_a     (ppu_out),
    .q_a        (ppu_in_vram)
);

endmodule

`include "../nes.v"
`include "../ppu.v"
