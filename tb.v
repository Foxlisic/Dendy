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
reg  [ 7:0] prg[65536];
reg  [ 7:0] vmm[65536];
reg  [ 7:0] oam[256];
wire [13:0] chra;
wire [ 7:0] oama;
reg  [ 7:0] chrd, prgi, oamd;
wire [15:0] A,    prga;
wire [ 7:0] I, D, prgd;
wire        R, W, prgw;
// ---------------------------------------------------------------------
wire        ce_cpu, nmi;
// ---------------------------------------------------------------------
initial begin

    $readmemh("pg.hex", prg, 16'h0000);
    $readmemh("ch.hex", vmm, 16'h0000);
    $readmemh("vm.hex", vmm, 16'h2000);
    $readmemh("sp.hex", oam,  8'h00);

    prg[16'hFFFA] = 8'h00; prg[16'hFFFB] = 8'h00; // NMI
    prg[16'hFFFC] = 8'h00; prg[16'hFFFD] = 8'h00; // RST
    prg[16'hFFFE] = 8'h04; prg[16'hFFFF] = 8'h00; // BRK

end
// ---------------------------------------------------------------------
always @(posedge clock)
begin

    prgi <= prg[prga];
    chrd <= vmm[chra];
    oamd <= oam[oama];

    if (prgw) prg[prga] <= prgd;

end

// Центральный процессор
// ---------------------------------------------------------------------
cpu DendyCPU
(
    .clock      (clock25),
    .reset_n    (reset_n),
    .ce         (1'b1),   // ce_cpu
    .nmi        (nmi),
    .A          (A),
    .I          (I),
    .D          (D),
    .R          (R),
    .W          (W)
);

// Видеопроцессор
// ---------------------------------------------------------------------
ppu DendyPPU
(
    .clock25    (clock25),
    .reset_n    (reset_n),
    .ce_cpu     (ce_cpu),
    .nmi        (nmi),
    // -- Видеопамять --
    .chra       (chra),
    .chrd       (chrd),
    .oama       (oama),
    .oamd       (oamd),
    // -- Память PRG --
    .prga       (prga),
    .prgi       (prgi),
    .prgd       (prgd),
    .prgw       (prgw),
    // -- Связь CPU --
    .cpu_a      (A),
    .cpu_i      (I),
    .cpu_o      (D),
    .cpu_w      (W),
    .cpu_r      (R)
);

endmodule
