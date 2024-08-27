/**
 * Процессор для DENDY
 */

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off CASEX */
/* verilator lint_off CASEOVERLAP */
/* verilator lint_off CASEINCOMPLETE */

module cpu
(
    // --- Управление, тактовая частота ---
    input               clock,      // 25 Mhz
    input               reset_n,    // ResetN
    input               ce,         // ChipEnabled
    input               nmi,        // Из PPU
    output              m0,         // Такт #0
    // --- Интерфейс работы с памятью ---
    output      [15:0]  A,          // Адрес
    input       [ 7:0]  I,          // Данные
    output reg  [ 7:0]  D,          // Выход
    output reg          R,          // Чтение
    output reg          W           // Запись
);

assign A  = m ? cp : pc;
assign m0 = (t == LOAD);

// Объявления
// ---------------------------------------------------------------------
localparam

    LOAD = 5'h00,  NDX = 5'h01,  NDY = 5'h02,  ABX = 5'h03,
    ABY  = 5'h04,  ABS = 5'h05,  REL = 5'h06,  RUN = 5'h07,
    ZP   = 5'h08,  ZPX = 5'h09,  ZPY = 5'h0A, NDX2 = 5'h0B,
    NDX3 = 5'h0C,  LAT = 5'h0D, NDY2 = 5'h0E, NDY3 = 5'h0F,
    ABS2 = 5'h10, ABXY = 5'h11, REL1 = 5'h12, REL2 = 5'h13,
    BRK  = 5'h14,  JSR = 5'h15, RTS  = 5'h16, RTI  = 5'h17;

// Номер АЛУ
localparam

    ORA = 0, AND = 1, EOR =  2, ADC =  3, STA =  4, LDA = 5, CMP =  6, SBC = 7,
    ASL = 8, ROL = 9, LSR = 10, ROR = 11, BIT = 12,          DEC = 14, INC = 15;

// Позиции флагов
localparam CF = 0, ZF = 1, IF = 2, DF = 3, BF = 4, VF = 6, SF = 7;
localparam IRQ_NMI = 2'b01, IRQ_RST = 2'b10, IRQ_BRK = 2'b11;
localparam

    DST_A = 2'b00, DST_X = 2'b01, DST_Y = 2'b10, DST_S = 2'b11,
    SRC_D = 2'b00, SRC_X = 2'b01, SRC_Y = 2'b10, SRC_A = 2'b11;

// Список всех регистров
// ---------------------------------------------------------------------
reg [ 7:0]  a, x, y, s, p;
reg [15:0]  pc;

// Состояние процессора
// ---------------------------------------------------------------------
reg         m;              // Выбор памяти =0 PC; =1 CP
reg         rd;             // =1 То читать из памяти =0 Писать
reg [ 4:0]  t;              // T-State
reg [ 2:0]  n;              // N-State
reg [15:0]  cp;             // Указатель памяти
reg [ 7:0]  opcode;         // Сохранение опкода
reg [ 7:0]  tr;             // Временный регистр
reg [ 1:0]  intr;           // =0 =1 =2 =3 USR
reg         cout;           // Перенос во время вычисления адресов
reg         cnext;          // =1 Разная задержка из-за инструкции
reg         nmitr;          // NMI сохранненый сигнал

// Вычисления
// ---------------------------------------------------------------------
wire [ 8:0] Xi      = x + I;
wire [ 8:0] Yi      = y + I;
wire [15:0] pcn     = pc + 1;
wire [15:0] pcr     = pcn + {{8{I[7]}}, I};
wire [15:0] cpn     = cp + 1;

// Сложение 16-битного адреса с переносом
wire [15:0] itr     = {I, tr};
wire [15:0] cpc     = itr + {cout, 8'h00};
wire [ 3:0] branch  = {p[ZF], p[CF], p[VF], p[SF]};

// Либо +1T, либо к RUN
wire [ 4:0] NEXT    = (cout || cnext) ? LAT : RUN;

// АЛУ
// ---------------------------------------------------------------------
reg  [ 3:0] alu;
reg  [ 1:0] dst_r, src_r;

// Левый [dst] и правый [src] операнд
wire [ 7:0] dst = dst_r == DST_A ? a : dst_r == DST_X ? x : dst_r == DST_Y ? y : s;
wire [ 7:0] src = src_r == SRC_D ? I : src_r == SRC_X ? x : src_r == SRC_Y ? y : a;

// Результат исполнения */
wire  [8:0] ar =

    // Арифметика
    alu == ORA ? dst | src :
    alu == AND ? dst & src :
    alu == EOR ? dst ^ src :
    alu == ADC ? dst + src + cin :
    alu == STA ? dst :
    alu == LDA ? src :
    alu == CMP ? dst - src :
    alu == SBC ? dst - src - !cin :
    // Сдвиги
    alu == ASL ? {src[6:0], 1'b0} :
    alu == ROL ? {src[6:0],  cin} :
    alu == LSR ? {1'b0, src[7:1]} :
    alu == ROR ? {cin,  src[7:1]} :
    // Разное
    alu == BIT ? dst & src :
    alu == DEC ? src - 1 :
    alu == INC ? src + 1 : src;

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
    alu[3:1] == 3'b010_ || // STA, LDA
    alu[3:1] == 4'b111_ ? {sf,       p[6:2], zf,    cin} : // INC, DEC
    alu[3:0] == 4'b0011 ? {sf, oadc, p[5:2], zf,  carry} : // ADC
    alu[3:0] == 4'b0111 ? {sf, osbc, p[5:2], zf, ~carry} : // SBC
    alu[3:0] == 4'b0110 ? {sf,       p[6:2], zf, ~carry} : // CMP
    alu[3:1] == 3'b100_ ? {sf,       p[6:2], zf, src[7]} : // ASL, ROL
    alu[3:1] == 3'b101_ ? {sf,       p[6:2], zf, src[0]} : // LSR, ROR
    alu[3:0] == 4'b1100 ? {src[7:6], p[5:2], zf,    cin} : 8'hFF; // BIT

// Исполнение опкодов
// ---------------------------------------------------------------------

always @(posedge clock)
// Вызов процедуры BRK #1 RESET
if (reset_n == 1'b0) begin

    t   <= BRK;
    m   <= 0;
    n   <= 0;
    a   <= 8'hC2;
    x   <= 8'h83;
    y   <= 8'h02;
    s   <= 8'h00;
    //            SV     ZC
    p       <= 8'b0000_0000;
    pc      <= 16'h0000;
    nmitr   <= 1'b0;
    intr    <= IRQ_RST;

end
// Процессор работает только если CE=1
else if (ce) begin

    R <= 0;
    W <= 0;

    case (t)

    // Загрузка опкода
    LOAD: begin

        cout    <= 0;
        cnext   <= 0;       // =1 Некоторые инструкции удлиняют такт +1
        rd      <= 1;       // =1 Используется для запроса чтения из PPU
        n       <= 0;       // ID микрокода RUN
        alu     <= I[7:5];  // АЛУ по умолчанию
        intr    <= IRQ_BRK; // USER BRK
        dst_r   <= DST_A;   // A
        src_r   <= SRC_D;   // DataIn

        // Прерывание NMI: срабатывает на восходящем сигнале
        if (nmitr ^ nmi && nmi) begin

            t     <= BRK;
            intr  <= IRQ_NMI;

        end else
        // Считывание опкода
        begin

            pc      <= pcn;
            opcode  <= I;

            casex (I)
            8'b001_000_00: begin t <= JSR; end
            8'b010_000_00: begin t <= RTI; end
            8'b011_000_00: begin t <= RTS; end
            8'b000_000_00: begin t <= BRK; pc <= pc + 2; end
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

            // АЛУ
            casex (I)
            // CPY
            8'hC0,
            8'hC4,
            8'hCC: begin alu <= CMP; dst_r <= DST_Y; end
            // CPX
            8'hE0,
            8'hE4,
            8'hEC: begin alu <= CMP; dst_r <= DST_X; end
            // TXA, TYA
            8'h8A: begin alu <= LDA; src_r <= SRC_X; end
            8'h98: begin alu <= LDA; src_r <= SRC_Y; end
            // TAX, TAY
            8'hAA,
            8'hA8: begin alu <= LDA; src_r <= SRC_A; end
            // BIT
            8'h24,
            8'h2C: begin alu <= BIT; end
            // DEX, INX, DEY, INY
            8'hCA: begin alu <= DEC; src_r <= SRC_X; end
            8'hE8: begin alu <= INC; src_r <= SRC_X; end
            8'h88: begin alu <= DEC; src_r <= SRC_Y; end
            8'hC8: begin alu <= INC; src_r <= SRC_Y; end
            // Сдвиги
            8'b0xx_xx1_10: begin alu <= ASL + I[6:5]; end
            8'b0xx_010_10: begin alu <= ASL + I[6:5]; src_r <= SRC_A; end
            // INC, DEC
            8'b11x_xx1_10: begin alu <= DEC + I[5]; end
            endcase

            // STX, STY, STA: Выбор источника для записи в память
            casex (I) 8'b100_xx1_10: D <= x; 8'b100_xx1_00: D <= y; default: D <= a; endcase

            // Для STA запретить RD, но разрешить WR
            casex (I) 8'b100_xxx_01, 8'b100_xx1_x0: rd <= 1'b0; endcase

            // INC, DEC, STA, Сдвиговые всегда добавляют +1Т к ABS,XY; IND,Y
            casex (I) 8'b100xxxxx, 8'b11xxx110, 8'b0xxxx110: cnext <= 1; endcase

        end

        nmitr <= nmi;

    end

    // Вычисление эффективного адреса
    // -------------------------------------------------------------

    // Indirect, X: Читать из #D+X значение 16-битного адреса
    NDX:  begin t <= NDX2; cp <= Xi[7:0];   pc <= pcn; m  <= 1; end
    NDX2: begin t <= NDX3; cp <= cpn;       tr <= I;   end
    NDX3: begin t <= LAT;  cp <= itr;       {R,W} <= {rd,~rd}; end

    // Indirect, Y: Читать из (#D) 16 битный адрес + Y
    NDY:  begin t <= NDY2; cp <= I;         m  <= 1; pc <= pcn; end
    NDY2: begin t <= NDY3; cp <= cpn[7:0];  {cout,tr} <= Yi; end
    NDY3: begin t <= NEXT; cp <= cpc;       {R,W} <= {rd,~rd}; end

    // ZP; ZPX; ZPY: Адресация ZeroPage
    ZP:   begin t <= RUN;  cp <= I;       m <= 1; {R,W} <= {rd,~rd}; pc <= pcn; end
    ZPX:  begin t <= LAT;  cp <= Xi[7:0]; m <= 1; {R,W} <= {rd,~rd}; pc <= pcn; end
    ZPY:  begin t <= LAT;  cp <= Yi[7:0]; m <= 1; {R,W} <= {rd,~rd}; pc <= pcn; end

    // Absolute: 16-битный адрес
    ABS:  begin t <= ABS2; tr <= I; pc <= pcn; end
    ABS2: begin

        if (opcode == 8'h4C) // 3T JMP ABS
             begin t <= LOAD; pc <= itr; end
        else begin t <= RUN;  cp <= itr; pc <= pcn; m <= 1; {R,W} <= {rd,~rd}; end

    end

    // Absolute,X: 16-битный адрес + X|Y
    ABX:  begin t <= ABXY; tr <= Xi[7:0]; pc <= pcn; cout <= Xi[8]; end
    ABY:  begin t <= ABXY; tr <= Yi[7:0]; pc <= pcn; cout <= Yi[8]; end
    ABXY: begin t <= NEXT; cp <= cpc;     pc <= pcn; m <= 1; {R,W} <= {rd,~rd}; end

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
    LAT:  begin t <= RUN;  end  // +1T к такту
    // -------------------------------------------------------------

    RUN: begin

        m <= 0;
        t <= LOAD;

        // Исполнение опкода
        casex (opcode) 8'bxxx_010_x1, 8'b1xx_000_x0: pc <= pcn; endcase
        casex (opcode)

        // Инструкция [6T] STA,STX,STY
        8'b100_xxx_01, 8'b100_xx1_x0: begin end

        // CLC, SEC; CLI, SEI; CLV; CLD, SED
        8'b00x_110_00: p[CF] <= opcode[5];
        8'b01x_110_00: p[IF] <= opcode[5];
        8'b101_110_00: p[VF] <= 1'b0;
        8'b11x_110_00: p[DF] <= opcode[5];

        // АЛУ [dst,D]; Сдвиги ACC; TRANSFER
        8'bxxx_xxx_01,
        8'b0xx_010_10,
        8'h8A, 8'h98: begin a <= ar[7:0]; p <= ap; end

        // LDX, LDY, TAX, TAY, DEX, DEY, INX, INY
        8'b101_xx1_10, 8'hA2, 8'hAA, 8'hCA, 8'hE8: begin x <= ar[7:0]; p <= ap; end
        8'b101_xx0_10, 8'hA0, 8'hA8, 8'h88, 8'hC8: begin y <= ar[7:0]; p <= ap; end

        // CP[XY] D :: BIT
        8'hC0,8'hC4,8'hC8,
        8'hE0,8'hE4,8'hE8,
        8'h24,8'h2C: begin p <= ap; end

        // TXS, TSX
        8'h9A: begin s <= x; end
        8'hBA: begin x <= s; p[ZF] <= (s == 0); p[SF] <= s[7]; end

        // Сдвиги, INC, DEC: Запись в память
        8'b0xx_xx1_10,
        8'b11x_xx1_10: case (n)

            0: begin n <= 1; t <= RUN; W <= 1; D <= ar; p <= ap; m <= 1; end
            1: begin n <= 2; t <= RUN; end

        endcase

        // JMP [INDIRECT]
        8'h6C: case (n)

            0: begin n <= 1; m <= 1; t <= RUN; tr <= I; cp[7:0] <= cp[7:0] + 1; end
            1: begin pc <= {I, tr}; end

        endcase

        // PHP, PHA
        8'h08, 8'h48: if (n == 0) begin

            t  <= RUN;
            m  <= 1;
            n  <= 1;
            cp <= {8'h01, s};
            D  <= opcode[6] ? a : (p | 8'h30);
            W  <= 1;
            s  <= s - 1;

        end

        // PLA, PLP
        8'h68, 8'h28: case (n)

            0: begin

                t <= RUN;
                n <= 1;
                m <= 1;
                s <= s + 1;

                cp[15:8] <= 8'h01;
                cp[ 7:0] <= s + 1;

            end

            1: begin

                n <= 2;
                t <= RUN;

                if (opcode[5]) p <= I;
                else     begin a <= I; p[ZF] <= I == 0; p[SF] <= I[7]; end

            end

        endcase

        endcase

    end

    // -------------------------------------------------------------

    // [7T] BRK или IRQ
    BRK: case (n)

        // PUSH((PC >> 8) & 0xff);
        // PUSH(PC & 0xff); SET_BREAK(1);
        // PUSH(SR); SET_INTERRUPT(1);
        0: begin n <= 1; cp <= {8'h01, s}; W <= 1; s <= s - 1; D <= pc[15:8]; m     <= 1; end
        1: begin n <= 2; cp[7:0] <= s;     W <= 1; s <= s - 1; D <= pc[7:0];  p[BF] <= 1; end
        2: begin n <= 3; cp[7:0] <= s;     W <= 1; s <= s - 1; D <= p;        p[IF] <= 1; end
        // LOAD ADDR
        3: begin n <= 4; cp    <= {12'hFFF, 1'b1, intr, 1'b0}; end
        4: begin n <= 5; cp[0] <= 1; tr <= I; end
        5: begin m <= 0; t <= LOAD;  pc <= {I, tr}; end

    endcase

    // [6T] Jump Subroutine
    JSR: case (n)

        0: begin n <= 1; tr <= I; pc <= pcn; cp[15:8] <= 8'h01; end
        1: begin n <= 2; cp[7:0] <= s; s <= s - 1; D <= pc[15:8]; W <= 1; pc[15:8] <= I; m <= 1; end
        2: begin n <= 3; cp[7:0] <= s; s <= s - 1; D <= pc[ 7:0]; W <= 1; end
        3: begin n <= 4; pc[7:0] <= tr; m <= 0; end
        4: begin t <= LOAD; end

    endcase

    // [6T] Возврат из процедуры
    RTS: case (n)

        0: begin n <= 1; m <= 1;        cp[7:0] <= s + 1; s <= s + 1; cp[15:8] <= 8'h01; end
        1: begin n <= 2; pc[7:0] <= I;  cp[7:0] <= s + 1; s <= s + 1; end
        2: begin n <= 3; pc      <= {I, pc[7:0]} + 1; m <= 0; end
        3: begin n <= 4; end
        4: begin t <= LOAD; end

    endcase

    // [6T] Возврат из прерывания
    RTI: case (n)

        0: begin n <= 1; cp[7:0]  <= s + 1; s <= s + 1; cp[15:8] <= 8'h01; m <= 1; end
        1: begin n <= 2; cp[7:0]  <= s + 1; s <= s + 1; p <= I; end
        2: begin n <= 3; cp[7:0]  <= s + 1; s <= s + 1; pc[7:0] <= I; end
        3: begin n <= 4; pc[15:8] <= I; m <= 0; end
        4: begin t <= LOAD; end

    endcase

    endcase

end

endmodule
