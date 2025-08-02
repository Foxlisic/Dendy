module c4
(
    input           RESET_N,
    input           CLOCK,          // 50 MHZ
    input   [3:0]   KEY,
    output  [3:0]   LED,
    output          BUZZ,           // Пищалка
    input           RX,             // Прием
    output          TX,             // Отправка
    output          SCL,            // Температурный сенсор :: LM75
    inout           SDA,
    output          I2C_SCL,        // Память 1Кб :: AT24C08
    inout           I2C_SDA,
    output          PS2_CLK,
    inout           PS2_DAT,
    input           IR,             // Инфракрасный приемник
    output          VGA_R,
    output          VGA_G,
    output          VGA_B,
    output          VGA_HS,
    output          VGA_VS,
    output  [ 3:0]  DIG,            // 4x8 Семисегментный
    output  [ 7:0]  SEG,
    inout   [ 7:0]  LCD_D,          // LCD экран
    output          LCD_E,
    output          LCD_RW,
    output          LCD_RS,
    inout   [15:0]  SDRAM_DQ,
    output  [11:0]  SDRAM_A,        // Адрес
    output  [ 1:0]  SDRAM_B,        // Банк
    output          SDRAM_RAS,      // Строка
    output          SDRAM_CAS,      // Столбце
    output          SDRAM_WE,       // Разрешение записи
    output          SDRAM_L,        // LDQM
    output          SDRAM_U,        // UDQM
    output          SDRAM_CKE,      // Активация тактов
    output          SDRAM_CLK,      // Такты
    output          SDRAM_CS        // Выбор чипа (=0)
);
// -----------------------------------------------------------------------------
assign BUZZ = 1'b1;
assign DIG  = 4'b1111;
assign LED  = 4'b1111;
// -----------------------------------------------------------------------------
assign {VGA_R,VGA_G,VGA_B} = {vga_r[3],vga_g[3],vga_b[3]};
// -----------------------------------------------------------------------------
wire [15:0] cpu_a;
wire [ 7:0] cpu_i, cpu_o;
wire        cpu_w, cpu_r;
wire        ce_cpu, nmi;
wire        clock_25, clock_100, reset_n;
// -----------------------------------------------------------------------------
reg  [ 7:0] joy1, joy2;
wire [ 3:0] vga_r, vga_g, vga_b;
// -----------------------------------------------------------------------------
wire [15:0] program_a;
wire [ 7:0] program_i;
wire [ 7:0] program_d;
wire        program_w;
// -----------------------------------------------------------------------------
wire [ 7:0] sram_i;
// -----------------------------------------------------------------------------
wire [14:0] video_a;
wire [ 7:0] video_i, video_d;
wire [ 7:0] video_o;
wire        video_w;
// -----------------------------------------------------------------------------
wire [14:0] chrom_a;
wire [ 7:0] chrom_i;
wire [ 7:0] chram_i;
// -----------------------------------------------------------------------------
wire [ 7:0] oam_a, oam_ax;
wire [ 7:0] oam_i, oam_ix, oam_o;
wire        oam_w;
// -----------------------------------------------------------------------------
wire [ 9:0] dub_a;
wire [ 7:0] dub_i, dub_o;
wire        dub_w;
// -----------------------------------------------------------------------------
// Запись в CHR-RxM  если позволяет маппер
wire        w_video    = (video_a[14:13] == 2'b00);    // [0000-1FFF]
wire        w_vdram    = (video_a[14:13] == 2'b01);    // [2000-3FFF]
wire        w_rom      = (program_a >= 16'h8000);      // [8000-FFFF] ПЗУ
wire        w_ram      = (program_a <  16'h2000);      // [0000-1FFF] ОЗУ

// Выбор источника данных для CHR-ROM; CHR-RAM
wire [7:0]  program_in = w_rom ? program_i : (w_ram ? sram_i : 8'hFF);
wire [7:0]  chrom_in   = chrom_a < 14'h2000 ? chrom_i : (chrom_a < 14'h3F00 ? chram_i : 8'hFF);
wire [7:0]  video_in   = video_a < 14'h2000 ? video_i : (video_a < 14'h3F00 ? video_d : 8'hFF);
// -----------------------------------------------------------------------------
pll P1
(
    .clock      (CLOCK),
    .c0         (clock_25),
    .c1         (clock_100),
    .reset_n    (reset_n)
);
// -----------------------------------------------------------------------------
cpu C1
(
    .clock      (clock_25),
    .reset_n    (reset_n),
    .ce         (ce_cpu),
    .nmi        (nmi),
    .A          (cpu_a),
    .I          (cpu_i),
    .D          (cpu_o),
    .R          (cpu_r),
    .W          (cpu_w)
);
// -----------------------------------------------------------------------------
ppu C2
(
    .clock25    (clock_25),
    .reset_n    (reset_n),
    .ce_cpu     (ce_cpu),
    .nmi        (nmi),
    // -- VGA --
    .r          (vga_r),
    .g          (vga_g),
    .b          (vga_b),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    // --- Процессор ---
    .cpu_a      (cpu_a),
    .cpu_i      (cpu_i),
    .cpu_o      (cpu_o),
    .cpu_r      (cpu_r),
    .cpu_w      (cpu_w),
    // --- Джойстики ---
    .joy1       (joy1),
    .joy2       (joy2),
    // -- PROGRAM ROM --
    .prga       (program_a),
    .prgi       (program_in),
    .prgd       (program_d),
    .prgw       (program_w),
    // -- VIDEO RAM --
    .vida       (video_a),
    .vidi       (video_in),
    .vido       (video_o),
    .vidw       (video_w),
    // -- CHR-ROM --
    .chra       (chrom_a),
    .chrd       (chrom_in),
    // -- OAM --
    .oama       (oam_ax),
    .oamd       (oam_ix),
    .oam2a      (oam_a),
    .oam2i      (oam_i),
    .oam2o      (oam_o),
    .oam2w      (oam_w),
    // -- Удвоение 2Y --
    .x2a        (dub_a),
    .x2i        (dub_i),
    .x2o        (dub_o),
    .x2w        (dub_w),
    // -- MAPPER --
    .mapper_cw  (1'b0),
    .mapper_nt  (1'b0),
);
// -----------------------------------------------------------------------------
// 32Кб хранилище программ
m32 PROGRAM
(
    .c  (clock_100),
    .a  (program_a[14:0]),
    .q  (program_i)
);

// 8Kb хранилище тайлов (ROM/RAM)
m8 CHRROM
(
    .c  (clock_100),
    .a  (chrom_a[12:0]),
    .q  (chrom_i),
    // --
    .ax (video_a[12:0]),
    .qx (video_i),
    .dx (video_o),
    .wx (video_w & w_video)
);
// -----------------------------------------------------------------------------
// 2Kb ОЗУ
m2 SRAM
(
    .c  (clock_100),
    .a  (program_a[10:0]),
    .q  (sram_i),
    .d  (program_d),
    .w  (program_w & w_ram)
);

// 2Kb Видеопамять тайлов
m2 VRAM
(
    .c  (clock_100),
    .a  (chrom_a[10:0]),
    .q  (chram_i),
    // --
    .ax (video_a[10:0]),
    .qx (video_d),
    .dx (video_o),
    .wx (video_w && w_vdram)
);

// 1Kb OAM
m1 OAM
(
    .c  (clock_100),
    .a  (oam_a),
    .q  (oam_i),
    .d  (oam_o),
    .w  (oam_w),
    .ax (oam_ax),
    .qx (oam_ix)
);

// 1Kb Скандаблер
m1 DUB
(
    .c (clock_100),
    .a (dub_a),
    .q (dub_i),
    .d (dub_o),
    .w (dub_w)
);
// -----------------------------------------------------------------------------
endmodule

`include "../cpu.v"
`include "../ppu.v"
