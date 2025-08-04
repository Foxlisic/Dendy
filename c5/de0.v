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
// -----------------------------------------------------------------------------
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
// -----------------------------------------------------------------------------
wire [15:0] cpu_a;
wire [ 7:0] cpu_i, cpu_o;
wire        cpu_w, cpu_r;
wire        ce_cpu, nmi;
wire [ 1:0] ct_cpu;
wire        clock_25, clock_100, reset_n;
// -----------------------------------------------------------------------------
reg  [ 7:0] joy1, joy2;
wire [ 7:0] kb_kbd;
wire        kb_hit;
reg         kb_press;
// -----------------------------------------------------------------------------
wire [15:0] program_a;
wire [17:0] program_m;
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
wire [ 7:0] dub_a;
wire [ 7:0] dub_i, dub_o;
wire        dub_w;
// -----------------------------------------------------------------------------
wire [ 1:0] cbank;
wire        mapper_cw, mapper_nt;
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
pll PLL0
(
    .clkin      (CLOCK_50),
    .m25        (clock_25),
    .m50        (clock_50),
    .m100       (clock_100),
    .locked     (reset_n)
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
    .ct_cpu     (ct_cpu),
    .nmi        (nmi),
    // -- VGA --
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
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
    .mapper_cw  (mapper_cw),
    .mapper_nt  (mapper_nt),
);
// Обработчик различных мапперов
// -----------------------------------------------------------------------------
mapper M1
(
    // Конфигурация
    .num        (8'h02),            // 02h UnROM
    .max        (4'b0111),          // 8 банков памяти
    // Интерфейс
    .clock      (clock_25),
    .reset_n    (reset_n),
    .ce_cpu     (ce_cpu),
    .ct_cpu     (ct_cpu),
    .cpu_a      (cpu_a),
    .cpu_o      (cpu_o),
    .cpu_w      (cpu_w),
    // Параметры картриджа
    .cw         (mapper_cw),
    .nt         (mapper_nt),
    .cbank      (cbank),
    .program_a  (program_a),
    .program_m  (program_m),
);
// -----------------------------------------------------------------------------
// 32Кб хранилище программ
m32 PROGRAM
(
    .c  (clock_100),
    .a  (program_m),
    .q  (program_i)
);

// 8Kb Хранилище тайлов (ROM/RAM)
m8 CHRROM
(
    .c  (clock_100),
    .a  ({cbank, chrom_a[12:0]}),
    .q  (chrom_i),
    // --
    .ax ({cbank, video_a[12:0]}),
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

// 4Kb Name Table
m4 VRAM
(
    .c  (clock_100),
    .a  (chrom_a[11:0]),
    .q  (chram_i),
    // --
    .ax (video_a[11:0]),
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

/*
joy SegaJoy1
(
    .clock      (clock_25),
    .pin_d1     (~GPIO_1[29]),
    .pin_d2     (~GPIO_1[28]),
    .pin_d3     (~GPIO_1[26]),
    .pin_d4     (~GPIO_1[27]),
    .pin_d6     (~GPIO_1[24]),
    .pin_d9     (~GPIO_1[25]),
    .pin_d7     ( GPIO_1[22]),
    .joy        (joy1)
);
*/

// -----------------------------------------------------------------------------
// Данные с джойстиков (с клавиатуры)
// https://ru.wikipedia.org/wiki/Скан-код
// -----------------------------------------------------------------------------

kb K1
(
    .clock  (clock_25),
    .reset_n(reset_n),
    .ps_clk (PS2_CLK),
    .ps_dat (PS2_DAT),
    .kbd    (kb_kbd),
    .hit    (kb_hit)
);

// Используются AT-коды клавиатуры
always @(posedge clock_25)
if (!reset_n) begin kb_press <= 1'b1; end
else if (kb_hit) begin

    // Код отпущенной клавиши
    if (kb_kbd == 8'hF0) kb_press <= 1'b0;
    else begin

        case (kb_kbd)

            8'h22: joy1[0] <= kb_press; // Z(B)
            8'h1A: joy1[1] <= kb_press; // X(A)
            8'h21: joy1[2] <= kb_press; // C(SEL)
            8'h2A: joy1[3] <= kb_press; // V(STA)
            8'h75: joy1[4] <= kb_press; // UP
            8'h72: joy1[5] <= kb_press; // DOWN
            8'h6B: joy1[6] <= kb_press; // LEFT
            8'h74: joy1[7] <= kb_press; // RIGHT

        endcase

        kb_press <= 1'b1;

    end

end

endmodule

`include "../cpu.v"
`include "../ppu.v"
`include "../kb.v"
`include "../mapper.v"
