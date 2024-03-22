module max10
(
    output wire [13:0] IO,
    output wire [ 3:0] LED,
    input  wire [ 1:0] KEY,
    input  wire        SERIAL_RX,
    output wire        SERIAL_TX,
    input  wire        CLK100MHZ
);

// Генерация частот
wire locked;
wire clock_25;

pll unit_pll
(
    .clk       (CLK100MHZ),
    .m25       (clock_25),
    .locked    (locked)
);

endmodule
