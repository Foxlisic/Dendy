`timescale 10ns / 1ns
module tb;
// ---------------------------------------------------------------------
reg         clock, clock25, reset_n;
always #0.5 clock       = ~clock;
always #2.0 clock25     = ~clock25;
// ---------------------------------------------------------------------
initial begin reset_n = 0; clock = 0; clock25 = 0; #3.0 reset_n = 1; #12000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
// ---------------------------------------------------------------------
reg  [ 7:0] ram[65536];
reg  [ 7:0] vmm[65536];
wire [15:0] chra, address;
reg  [ 7:0] chrd, in;
wire [ 7:0] out;
wire        we;
// ---------------------------------------------------------------------
wire        ce_cpu;
// ---------------------------------------------------------------------
initial begin

    $readmemh("tb.hex", ram, 16'h0000);
    $readmemh("ch.hex", vmm, 16'h0000);
    $readmemh("vm.hex", vmm, 16'h2000);

end
// ---------------------------------------------------------------------
always @(posedge clock)
begin

    in   <= ram[address];
    chrd <= vmm[chra];
    if (we) ram[address] <= out;

end

// Центральный процессор
// ---------------------------------------------------------------------
cpu DendyCPU
(
    .clock      (clock25),
    .reset_n    (reset_n),
    .A          (address),
    .I          (in),
    .D          (out),
    .W          (we)
);

// Видеопроцессор
// ---------------------------------------------------------------------
ppu DendyPPU
(
    .clock25    (clock25),
    .reset_n    (reset_n),
    .ce_cpu     (ce_cpu),
    .chra       (chra),
    .chrd       (chrd)
);

endmodule
