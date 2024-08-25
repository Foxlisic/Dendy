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
reg  [ 7:0] oam[256];
wire [15:0] address;
wire [13:0] chra;
reg  [ 7:0] chrd, in, oamd;
wire [ 7:0] out, oama;
wire        we;
// ---------------------------------------------------------------------
wire        ce_cpu;
// ---------------------------------------------------------------------
initial begin

    $readmemh("tb.hex", ram, 16'h0000);
    $readmemh("ch.hex", vmm, 16'h0000);
    $readmemh("vm.hex", vmm, 16'h2000);
    $readmemh("sp.hex", oam,  8'h00);

end
// ---------------------------------------------------------------------
always @(posedge clock)
begin

    in   <= ram[address];
    chrd <= vmm[chra];
    oamd <= oam[oama];

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
    .chrd       (chrd),
    .oama       (oama),
    .oamd       (oamd)
);

endmodule
