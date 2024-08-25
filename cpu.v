/**
 * Процессор для DENDY
 */

module cpu
(
    // --- Управление, тактовая частота ---
    input               clock,      // 25 Mhz
    input               reset_n,    // ResetN
    input               ce,         // ChipEnabled
    // --- Интерфейс работы с памятью ---
    output      [15:0]  A,          // Адрес
    input       [ 7:0]  I,          // Данные
    output reg  [ 7:0]  D,          // Выход
    output reg          R,          // Чтение
    output reg          W           // Запись
);

assign A = m ? cp : pc;

// Объявления
// ---------------------------------------------------------------------
localparam

    LOAD = 0,  NDX  = 1,  NDY  = 2,  ABX  = 3,
    ABY  = 4,  ABS  = 5,  REL  = 6,  RUN  = 7,
    ZP   = 8,  ZPX  = 9,  ZPY  = 10, NDX2 = 11,
    NDX3 = 12, LAT  = 13, NDY2 = 14, NDY3 = 15,
    ABS2 = 16, ABXY = 17, REL1 = 18, REL2 = 19;

// Позиции флагов
localparam CF = 0, ZF = 1, IF = 2, DF = 3, BF = 4, VF = 6, SF = 7;

// Список всех регистров
// ---------------------------------------------------------------------
reg [7:0]   a, x, y, s, p;
reg [15:0]  pc;

// Состояние процессора
// ---------------------------------------------------------------------
reg         m;              // Выбор памяти =0 PC; =1 CP
reg         rd;             // =1 То читать из памяти =0 Писать
reg [ 5:0]  t;              // T-State
reg [15:0]  cp;             // Указатель памяти
reg [ 7:0]  opcode;         // Сохранение опкода
reg [ 7:0]  tr;             // Временный регистр
reg         cout;           // Перенос во время вычисления адресов
reg         cnext;          // =1 Разная задержка из-за инструкции

// Вычисления
// ---------------------------------------------------------------------
wire [8:0]  Xi      = x + I;
wire [8:0]  Yi      = y + I;
wire [15:0] pcn     = pc + 1;
wire [15:0] pcr     = pcn + {{8{I}}, I};
wire [15:0] cpn     = cp + 1;

// Сложение 16-битного адреса с переносом
wire [15:0] itr     = {I, tr};
wire [15:0] cpc     = itr + {cout, 8'h00};
wire [ 3:0] branch  = {p[ZF], p[CF], p[VF], p[SF]};

// Либо +1T, либо к RUN
wire [ 5:0] NEXT    = (cout || cnext) ? LAT : RUN;

// АЛУ
// ---------------------------------------------------------------------
reg [ 3:0]  alu;
reg [ 7:0]  dst, src;

// Результат исполнения */
wire  [8:0] ar =

    // Арифметика
    alu == /* ORA */ 4'b0000 ? dst | src :
    alu == /* AND */ 4'b0001 ? dst & src :
    alu == /* EOR */ 4'b0010 ? dst ^ src :
    alu == /* ADC */ 4'b0011 ? dst + src + cin :
    alu == /* STA */ 4'b0100 ? dst :
    alu == /* LDA */ 4'b0101 ? src :
    alu == /* CMP */ 4'b0110 ? dst - src :
    alu == /* SBC */ 4'b0111 ? dst - src - !cin :
    // Сдвиги
    alu == /* ASL */ 4'b1000 ? {src[6:0], 1'b0} :
    alu == /* ROL */ 4'b1001 ? {src[6:0],  cin} :
    alu == /* LSR */ 4'b1010 ? {1'b0, src[7:1]} :
    alu == /* ROR */ 4'b1011 ? {cin,  src[7:1]} :
    // Разное
    alu == /* BIT */ 4'b1101 ? dst & src :
    alu == /* DEC */ 4'b1110 ? src - 1 :
    alu == /* INC */ 4'b1111 ? src + 1 : src;

// Статусы ALU
wire zf     = ar[7:0] == 0;
wire sf     = ar[7];
wire oadc   = (dst[7] ^ src[7] ^ 1'b1) & (dst[7] ^ ar[7]); // Переполнение ADC
wire osbc   = (dst[7] ^ src[7]       ) & (dst[7] ^ ar[7]); // Переполнение SBC
wire cin    =  p[CF];
wire carry  = ar[8];

// Вычисление флагов
wire [7:0] ap =

    alu[3:1] == 3'b000_ || // ORA, AND
    alu[3:0] == 4'b0010 || // EOR
    alu[3:1] == 3'b010_ || // STA, LDA :: INC, DEC
    alu[3:1] == 4'b111_ ? {sf,       p[6:2], zf,  cin} :
    alu[3:0] == 4'b0011 ? {sf, oadc, p[5:2], zf,  carry} : // ADC
    alu[3:0] == 4'b0111 ? {sf, osbc, p[5:2], zf, ~carry} : // SBC
    alu[3:0] == 4'b0110 ? {sf,       p[6:2], zf, ~carry} : // CMP
    alu[3:1] == 3'b100_ ? {sf,       p[6:2], zf, src[7]} : // ASL, ROL
    alu[3:1] == 3'b101_ ? {sf,       p[6:2], zf, src[0]} : // LSR, ROR
    alu[3:0] == 4'b1101 ? {dst[7:6], p[5:2], zf, cin} : 8'hFF; // BIT

// Исполнение опкодов
// ---------------------------------------------------------------------

always @(posedge clock)
// Вызов процедуры BRK #1 RESET
if (reset_n == 1'b0) begin

    t   <= 0;
    m   <= 0;
    a   <= 8'h00;
    x   <= 8'h00;
    y   <= 8'h00;
    s   <= 8'h00;
    p   <= 8'h00;
    pc  <= 16'h0000;

end
// Процессор работает только если CE=1
else if (ce) begin

    R <= 0;
    W <= 0;

    case (t)

    // Загрузка опкода
    LOAD: begin

        pc      <= pcn;
        opcode  <= I;
        cnext   <= 0;       // =1 Некоторые инструкции удлиняют такт +1
        rd      <= 0;       // =1 Используется для запроса чтения из PPU

        casex (I)
        8'bxxx_000_x1: begin t <= NDX; end  // Indirect,X
        8'bxxx_010_x1,
        8'b1xx_000_x0: begin t <= RUN; end  // Immediate
        8'bxxx_100_x1: begin t <= NDY; end  // Indirect,Y
        8'bxxx_110_x1: begin t <= ABY; end  // Absolute,Y
        8'bxxx_001_xx: begin t <= ZP;  end  // ZeroPage
        8'bxxx_011_xx, // Absolute
        8'b001_000_00: begin t <= ABS; end
        8'b10x_101_1x: begin t <= ZPY; end  // ZeroPage,Y
        8'bxxx_101_xx: begin t <= ZPX; end  // ZeroPage,X
        8'b10x_111_1x: begin t <= ABY; end  // Absolute,Y
        8'bxxx_111_xx: begin t <= ABX; end  // Absolute,X
        8'bxxx_100_00: begin t <= REL; end  // Relative
        8'b0xx_010_10: begin t <= RUN; end  // Accumulator
        default:       begin t <= RUN; end
        endcase

        // Для STA запретить RD
        casex (I) 8'b100_xxx_01, 8'b100_xx1_x0: rd <= 1'b0; endcase

        // INC, DEC, STA, Сдвиговые
        casex (I) 8'b100xxxxx, 8'b11xxx110, 8'b0xxxx110: cnext <= 1; endcase

    end

    // Вычисление эффективного адреса
    // -------------------------------------------------------------

    // Indirect, X: Читать из #D+X значение 16-битного адреса
    NDX:  begin t <= NDX2; cp <= Xi[7:0];   m  <= 1;  end
    NDX2: begin t <= NDX3; cp <= cpn;       tr <= I;  end
    NDX3: begin t <= LAT;  cp <= itr;       R  <= rd; end

    // Indirect, Y: Читать из (#D) 16 битный адрес + Y
    NDY:  begin t <= NDY2; cp <= I;         m  <= 1; end
    NDY2: begin t <= NDY3; cp <= cpn[7:0];  {cout,tr} <= Yi; end
    NDY3: begin t <= NEXT; cp <= cpc;       R <= rd; end

    // ZP; ZPX; ZPY: Адресация ZeroPage
    ZP:   begin t <= RUN;  cp <= I;       m <= 1; R <= rd; end
    ZPX:  begin t <= LAT;  cp <= Xi[7:0]; m <= 1; R <= rd; end
    ZPY:  begin t <= LAT;  cp <= Yi[7:0]; m <= 1; R <= rd; end

    // Absolute: 16-битный адрес
    ABS:  begin t <= ABS2; tr <= I; pc <= pcn; end
    ABS2: begin

        if (opcode == 8'h4C) // 3T JMP ABS
             begin t <= LOAD; pc <= itr; end
        else begin t <= RUN;  cp <= itr; m <= 1; R <= rd; end

    end

    // Absolute,X: 16-битный адрес + X|Y
    ABX:  begin t <= ABXY; tr <= Xi[7:0]; pc <= pcn; cout <= Xi[8]; end
    ABY:  begin t <= ABXY; tr <= Yi[7:0]; pc <= pcn; cout <= Yi[8]; end
    ABXY: begin t <= NEXT; cp <= cpc;     m <= 1;    R <= rd; end

    // Условный переход
    // -------------------------------------------------------------
    REL: begin

        if (branch[opcode[7:6]] == opcode[5]) begin

            t  <= pcr[15:8] == pc[15:8] ? REL2 : REL1;
            pc <= pcr;

        end
        else begin pc <= pcn; t <= LOAD; end

    end

    REL1: begin t <= REL2; end  // +2T если превышение границ
    REL2: begin t <= LOAD; end  // +1T если переход
    // -------------------------------------------------------------

    endcase

end

endmodule
