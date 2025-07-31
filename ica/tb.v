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
wire debugcpu = 0;
// ---------------------------------------------------------------------
reg  [ 7:0] prg[65536];
reg  [ 7:0] vmm[65536];
reg  [ 7:0] oam[256];
wire [14:0] chra, vida;
wire [ 7:0] oama, oam2a, vido;
reg  [ 7:0] chrd, prgi, oamd, oam2i, vidi, Ix;
wire [15:0] A,    prga;
wire [ 7:0] I, D, prgd, oam2o;
wire        R, W, prgw, oam2w;
// ---------------------------------------------------------------------
wire        ce_cpu, nmi;
// ---------------------------------------------------------------------
initial begin

    $readmemh("mem_pg.hex", prg, 16'h0000);
    $readmemh("mem_ch.hex", vmm, 16'h0000);
    $readmemh("mem_vm.hex", vmm, 16'h2000);
    $readmemh("mem_sp.hex", oam,  8'h00);

    prg[16'hFFFA] = 8'h00; prg[16'hFFFB] = 8'h00; // NMI
    prg[16'hFFFC] = 8'h00; prg[16'hFFFD] = 8'h00; // RST
    prg[16'hFFFE] = 8'h04; prg[16'hFFFF] = 8'h00; // BRK

end
// ---------------------------------------------------------------------
always @(posedge clock)
begin

    prgi  <= prg[prga];
    chrd  <= vmm[chra];
    oamd  <= oam[oama];
    oam2i <= oam[oam2a];
    vidi  <= vmm[vida];

    // if (prgw)  prg[prga]  <= prgd;
    if (oam2w) oam[oam2a] <= oam2o;
    if (vidw)  vmm[vida]  <= vido;

    Ix <= prg[A]; if (W) prg[A] <= D;

end

// Центральный процессор
// ---------------------------------------------------------------------
cpu DendyCPU
(
    .clock      (clock25),
    .reset_n    (reset_n),
    .ce         (debugcpu | ce_cpu),
    .nmi        (nmi),
    .A          (A),
    .I          (debugcpu ? Ix : I),
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
    // ---
    .vida       (vida),
    .vidi       (vidi),
    .vido       (vido),
    .vidw       (vidw),
    // ---
    .oama       (oama),
    .oamd       (oamd),
    // ---
    .oam2a      (oam2a),
    .oam2i      (oam2i),
    .oam2o      (oam2o),
    .oam2w      (oam2w),
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
    .cpu_r      (R),
    .joy1       (8'hAF)
);

endmodule

`include "../cpu.v"
`include "../ppu.v"