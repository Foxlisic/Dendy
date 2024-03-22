module max10
(
    output wire [13:0] IO,
    output wire [ 3:0] LED,
    input  wire [ 1:0] KEY,
    input  wire        SERIAL_RX,
    output wire        SERIAL_TX,
    input  wire        CLK100MHZ
);

assign IO[7:0] = out;

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
// 2K RAM;  4K PRG-ROM Ограниченная память PRG
// 2K VRAM; 4K PRG-ROM Спрайты не поддерживаются, 2 окна
// -----------------------------------------------------------------------------

wire is_ram = (address <  16'h2000),
     is_rom = (address >= 16'h8000);

wire [ 7:0] in =
    is_ram ? in_ram :
    is_rom ? in_rom : 8'hFF;

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

endmodule

`include "../nes.v"
