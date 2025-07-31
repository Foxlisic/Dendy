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

assign BUZZ = 1'b1;
assign DIG  = 4'b1111;

// CPU Wire
// ---------------------------------------------------------------------
wire [15:0] cpu_a;
wire [ 7:0] cpu_i, cpu_o;
wire        ce_cpu, nmi, cpu_w, cpu_r;
wire        clock_25, clock_100, reset_n;
// ---------------------------------------------------------------------
pll P1
(
    .clock      (CLOCK),
    .c0         (clock_25),
    .c1         (clock_100),
    .reset_n    (reset_n)
);
// ---------------------------------------------------------------------
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
    .W          (cpu_w),
);
// ---------------------------------------------------------------------

endmodule

`include "../cpu.v"
`include "../ppu.v"
