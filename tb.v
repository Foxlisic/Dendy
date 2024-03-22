`timescale 10ns / 1ns

module tb;
// ---------------------------------------------------------------------
reg reset_n;
reg clock;     always #0.5 clock    = ~clock;
reg clock_25;  always #1.0 clock_25 = ~clock_25;
// ---------------------------------------------------------------------
initial begin reset_n = 0; irq = 0; clock = 0; clock_25 = 0; #2.5 reset_n = 1; #7.5 irq = 1; #15.0 irq = 0; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial begin $readmemh("tb.hex", memory, 0); end
initial begin
    memory[16'hFFFA] = 8'h04; memory[16'hFFFB] = 8'h00;  // NMI
    memory[16'hFFFC] = 8'h00; memory[16'hFFFD] = 8'h00;  // RESET
    memory[16'hFFFE] = 8'h01; memory[16'hFFFF] = 8'h00;  // BRK
end
// ---------------------------------------------------------------------
reg  [ 7:0] memory[65536]; // Чистая теория
wire [15:0] address;
wire [ 7:0] out;
reg  [ 7:0] in;
wire        we, rd;
reg         irq;

// Здесь посложнее будет позже
always @(posedge clock) begin in <= memory[address]; if (we) memory[address] <= out; end
// ---------------------------------------------------------------------

nes CPU6502
(
    .clock      (clock_25),
    .locked     (1'b1),
    .reset_n    (reset_n),
    .address    (address),
    .irq        (irq),
    .in         (in),
    .out        (out),
    .we         (we),
    .rd         (rd)
);

endmodule
