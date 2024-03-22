/* verilator lint_off WIDTH */
/* verilator lint_off CASEX */
/* verilator lint_off CASEOVERLAP */
/* verilator lint_off CASEINCOMPLETE */

module nes
(
    input               clock,
    input               locked,
    input               reset_n,
    input               irq,
    output      [15:0]  address,
    input       [ 7:0]  in,
    output reg  [ 7:0]  out,
    output reg          we,
    output reg          rd
);

// Источник памяти
assign address = mm ? cp : pc;

// Способы адресации
localparam

    MAIN = 8'h00,
    ZP   = 8'h01, ZPX  = 8'h02, ZPY  = 8'h03,
    ABS  = 8'h04, JSR  = 8'h05, IND  = 8'h06,
    ABX  = 8'h07, ABY  = 8'h08, REL  = 8'h09,
    NDX  = 8'h0A, NDY  = 8'h0B, RUN  = 8'h0C,
    DLY  = 8'h0D, ABS2 = 8'h0E, ABX2 = 8'h0F,
    NDX2 = 8'h10, NDX3 = 8'h11, NDY2 = 8'h12,
    NDY3 = 8'h13, REL2 = 8'h14, REL3 = 8'h15,
    RTS  = 8'h16, BRK  = 8'h17, RTI  = 8'h18;

// АЛУ
localparam
    ORA =  0, AND =  1, EOR =  2, ADC =  3,
    STA =  4, LDA =  5, CMP =  6, SBC =  7,
    INC =  8, DEC =  9, ASL = 10, ROL = 11,
    LSR = 12, ROR = 13, BIT = 14;

localparam
    DST_A = 0, DST_X = 1, DST_Y = 2, DST_D = 3,
    SRC_D = 0, SRC_A = 1, SRC_X = 2, SRC_Y = 3;

// Флаги
localparam
    CF = 0, ZF = 1, IF = 2, DF = 3,
    BF = 4, XF = 5, VF = 6, NF = 7;

// Регистры и состояние процессора
// -----------------------------------------------------------------------------
reg [ 7:0]  a, x, y, p, s;
reg         mm, sta, utk, irq_prev;
reg [15:0]  pc, cp;
reg [ 7:0]  op, tm;
reg [ 6:0]  t;
reg [ 2:0]  m;
reg [ 3:0]  alu;
reg [ 1:0]  src, dst, vec;

// Вычисление проводов
// -----------------------------------------------------------------------------
wire [15:0] pcn = pc + {{8{in[7]}},in} + 1;
wire [15:0] pc2 = pc + 2;
wire [ 7:0] zpx = x + in,
            zpy = y + in;
wire [ 8:0] ndy = tm + y;
wire [ 7:0] sm  = s - 1,
            sp  = s + 1;
wire [ 3:0] brc = {p[NF], p[CF], p[VF], p[ZF]};

// Учитывать дополнительный такт (utk=1 всегда учитывать)
wire        nx1 = sta || cp[8]  || utk;
wire        nx2 = sta || ndy[8] || utk;

// Основная логика
// -----------------------------------------------------------------------------
always @(posedge clock)
// Сброс процессора
if (reset_n == 1'b0) begin

    t   <= BRK;
    vec <= 2'b10;       // RESET
    m   <= 3;
    pc  <= 16'h0000;
    mm  <= 1;
    we  <= 0;
    a   <= 8'h84;
    x   <= 8'h4F;
    y   <= 8'h00;
    s   <= 8'h3F;
    //        NVxBDIZC
    p   <= 8'b01000001;

end
// Исполнение опкодов
else if (locked) begin

    rd <= 1'b0;
    we <= 1'b0;

    case (t)

        // Считывание и разбор опкода
        MAIN: begin

            t    <= 1;
            m    <= 0;
            op   <= in;
            pc   <= pc + 1;
            alu  <= in[7:5];
            dst  <= DST_A;
            src  <= SRC_D;
            sta  <= 0;
            utk  <= 0;
            out  <= a;
            vec  <= 2'b11;
            irq_prev <= irq;

            casex (in)
            // Специальные
            8'b000_000_00: t <= BRK;
            8'b001_000_00: t <= JSR;
            8'b010_000_00: t <= RTI;
            8'b011_000_00: t <= RTS;
            8'b011_011_00: t <= IND;
            8'b10x_101_10: t <= ZPY;
            // Общие
            8'bxxx_001_xx: t <= ZP;
            8'bxxx_101_xx: t <= ZPX;
            8'bxxx_011_xx: t <= ABS;
            8'bxxx_111_xx: t <= ABX;
            8'bxxx_110_x1: t <= ABY;
            8'bxxx_000_x1: t <= NDX;
            8'bxxx_100_x1: t <= NDY;
            8'bxxx_100_00: t <= REL;
            default:       t <= RUN; // ACC, IMP, IMM , IND
            endcase

            // Выбор АЛУ
            casex (in)
            8'b1010_00x0,
            8'b101x_x110, // LDX, LDY
            8'b101x_x100: begin alu <= LDA; end
            8'b1110_0000,
            8'b1110_x100: begin dst <= DST_X; alu <= CMP; end
            8'b1100_0000,
            8'b1100_x100: begin dst <= DST_Y; alu <= CMP; end
            // DEX, DEY
            8'b1000_1000: begin dst <= DST_Y; alu <= DEC; end // 88 DEY
            8'b1100_1000: begin dst <= DST_Y; alu <= INC; end // C8 INY
            8'b1100_1010: begin dst <= DST_X; alu <= DEC; end // CA DEX
            8'b1110_1000: begin dst <= DST_X; alu <= INC; end // E8 INX
            // INC, DEC
            8'b110x_x110: begin dst <= DST_D; alu <= DEC; utk <= 1; end
            8'b111x_x110: begin dst <= DST_D; alu <= INC; utk <= 1; end
            // ASL, ROR, LSR, ROL [MEM|ACC]
            8'b0xxx_x110: begin alu <= ASL + in[6:5]; dst <= DST_D; utk <= 1; end
            8'b0xx0_1010: begin alu <= ASL + in[6:5]; end
            8'b0010_x100: begin alu <= BIT; end
            // TRANSFER
            8'b1001_1000: begin alu <= LDA; src <= SRC_Y; end // TYA
            8'b1010_10x0: begin alu <= LDA; src <= SRC_A; end // TAX, TAY
            8'b1000_1010: begin alu <= LDA; src <= SRC_X; end // TXA
            endcase

            // Вызов аппаратного прерывания NMI
            if ({irq_prev, irq} == 2'b01) begin pc <= pc - 2; vec <= 2'b01; t <= BRK; end
            else begin

                // Дополнительная обработка инструкции
                casex (in)
                8'b100x_xx01: begin sta <= 1; end           // STA
                8'b100x_x110: begin sta <= 1; out <= x; end // STX
                8'b100x_x100: begin sta <= 1; out <= y; end // STY
                // PHP, PHA
                8'b0x00_1000: begin cp <= {8'h01, s};  s <= sm; out <= in[6] ? a : p | 8'h30; end
                8'b0x10_1000: begin cp <= {8'h01, sp}; s <= sp; mm  <= 1; end
                endcase

            end

        end

        // Разбор метода адресации
        // ---------------------------------------------------------------------

        // 3*T ZEROPAGE
        ZP:   begin t <= RUN; pc <= pc + 1; mm <= 1; cp <= in;  we <= sta; rd <= !sta; end
        ZPX:  begin t <= DLY; pc <= pc + 1; mm <= 1; cp <= zpx; we <= sta; end
        ZPY:  begin t <= DLY; pc <= pc + 1; mm <= 1; cp <= zpy; we <= sta; end

        // 4T ABSOLUTE, JMP
        ABS:  begin t <= ABS2; pc <= pc + 1; cp[7:0] <= in; end
        ABS2: begin

            if (op == 8'h4C) // JMP ABS
                 begin t <= MAIN; pc <= {in, cp[7:0]}; end
            else begin t <= RUN;  pc <= pc + 1; cp[15:8] <= in; mm <= 1; {we, rd} <= {sta, !sta}; end

        end

        // 4*T ABSOLUTE,INDEX
        ABX:  begin t <= ABX2; pc <= pc + 1; cp <= in + x; end
        ABY:  begin t <= ABX2; pc <= pc + 1; cp <= in + y; end
        ABX2: begin t <= nx1 ? DLY : RUN; pc <= pc + 1; cp <= cp + {in, 8'h00}; mm <= 1; we <= sta; rd <= !nx1; end

        // 6T INDIRECT,X
        NDX:  begin t <= NDX2; pc <= pc + 1; cp <= zpx; mm <= 1; end
        NDX2: begin t <= NDX3; cp[7:0] <= cp[7:0] + 1; tm <= in; end
        NDX3: begin t <= DLY;  cp <= {in, tm}; we <= sta; end

        // 5*T INDIRECT,Y
        NDY:  begin t <= NDY2; mm <= 1;   cp <= in; pc <= pc + 1; end
        NDY2: begin t <= NDY3; tm <= in;  cp[7:0] <= cp[7:0] + 1; end
        NDY3: begin t <= nx2 ? DLY : RUN; cp <= {in, 8'h00} + ndy; we <= sta; rd <= !nx2; end

        // 2**T BRANCH
        REL:  begin if (brc[op[7:6]] == op[5]) t <= REL2; else begin t <= MAIN; pc <= pc + 1; end end
        REL2: begin pc <= pcn; t <= (pc[15:8] != pcn[15:8]) ? REL3 : MAIN; end
        REL3: begin t  <= MAIN; end

        // 1T Задержка для ZPX, ZPY, ABX, ABY
        DLY:  begin rd <= !sta; t <= RUN; end

        // Выполнение инструкции
        // ---------------------------------------------------------------------

        RUN: begin

            t  <= MAIN;
            mm <= 0;

            // Immediate: добавляется +1 к PC
            casex (op) 8'b1xx_000_x0, 8'bxxx_010_x1: pc <= pc + 1; endcase

            casex (op)
            // Флаговые CLC, SEC, CLI, SEI, CLD, SED, CLV
            8'b00x1_1000: p[CF] <= op[5];
            8'b01x1_1000: p[IF] <= op[5];
            8'b11x1_1000: p[DF] <= op[5];
            8'b1011_1000: p[VF] <= 1'b0;
            // TXS, TSX
            8'b1001_1010: begin s <= x; end
            8'b1011_1010: begin x <= s; {p[NF], p[ZF]} <= {s[7], s == 8'h00}; end
            // Запись АЛУ в X
            8'b101x_x110, // LDX ADDR
            8'b1010_x010, // LDX IMM; TAX
            8'b1100_1010, // DEX
            8'b1110_1000: // INX
                begin x <= alur; p <= aluf; end
            // Запись АЛУ в Y
            8'b101x_x100, // LDY ADDR
            8'b1010_x000, // LDY IMM; TAY
            8'b1x00_1000: // DEY, INY
                begin y <= alur; p <= aluf; end
            // Запись только флагов
            8'b11x0_0000, // CPX, CPY IMM
            8'b0010_x100, // BIT
            8'b11x0_x100: // CPX, CPY ADDR
                begin p <= aluf; end
            // Запись в память
            8'b11xx_x110, // INC, DEC
            8'b0xxx_x110: // ASL, LSR, ROL, ROR
                case (m)
                0: begin m <= 1; t <= RUN; mm <= 1; we <= 1; out <= alur; p <= aluf; end
                1: begin m <= 2; t <= RUN; end
                endcase
            // PHP, PHA
            8'b0x00_1000:
                case (m) 0: begin m <= 1; t <= RUN; mm <= 1; we <= 1; end endcase
            // PLA, PLP
            8'b0x10_1000:
                case (m)
                0: begin

                    m <= 1;
                    t <= RUN;
                    if (op[6]) begin a <= in; {p[NF], p[ZF]} <= {in[7], in == 8'h00}; end
                    else       begin p <= in; end

                end
                1: begin m <= 2; t <= RUN; end
                endcase
            // STA
            8'b100x_xx01:
                begin /* Иначе выполнится запись в A,P */ end
            // Запись в [A,P]
            8'bxxxx_xx01, // АЛУ
            8'b0xx0_1010, // ASL, ROR, LSR, ROL
            8'b1001_1000, // TYA
            8'b1000_1010: // TXA
                begin a <= (alu == CMP) ? a : alur; p <= aluf; end
            endcase

        end

        // ---------------------------------------------------------------------

        // 5T JMP (IND)
        IND: case (m)
        0: begin m  <= 1; cp[ 7:0] <= in; pc <= pc + 1; end
        1: begin m  <= 2; cp[15:8] <= in; mm <= 1; end
        2: begin m  <= 3; pc[ 7:0] <= in; cp <= cp + 1; end
        3: begin mm <= 0; pc[15:8] <= in; t <= MAIN; end
        endcase

        // 6T JUMP SUB
        JSR: case (m)
        0: begin m <= 1; pc  <= pc + 1;   tm <= in; end
        1: begin m <= 2; out <= pc[15:8]; tm <= pc[7:0]; cp <= s; s <= sm; pc <= {in, tm}; we <= 1; mm <= 1; end
        2: begin m <= 3; out <= tm;       we <= 1;       cp <= s; s <= sm; end
        3: begin m <= 4; mm <= 0; end
        4: begin t <= MAIN; end
        endcase

        // 7T BREAK
        BRK: case (m)
        0: begin m <= 1; we <= 1; cp <= s; s <= sm; out <= pc2[15:8]; mm <= 1; end
        1: begin m <= 2; we <= 1; cp <= s; s <= sm; out <= pc2[ 7:0]; end
        2: begin m <= 3; we <= 1; cp <= s; s <= sm; out <= p | 8'h10; p <= p | 8'h14; end
        3: begin m <= 4; cp    <= {12'hFFF, 1'b1, vec, 1'b0}; end
        4: begin m <= 5; cp[0] <= 1'b1; pc[7:0] <= in; end
        5: begin t <= MAIN; pc[15:8] <= in; mm <= 0; end
        endcase

        // 6T RETURN SUB
        RTS: case (m)
        0: begin m <= 1; mm <= 1;  cp <= sp; s <= sp; end
        1: begin m <= 2; pc <= in; cp <= sp; s <= sp; end
        2: begin m <= 3; pc <= pc + {in, 8'h01}; end
        3: begin m <= 4; mm <= 0; end
        4: begin t <= MAIN; end
        endcase

        // 6T RETURN BRK
        RTI: case (m)
        0: begin m <= 1; cp <= sp; s <= sp; mm <= 1; end
        1: begin m <= 2; cp <= sp; s <= sp; p  <= in; end
        2: begin m <= 3; cp <= sp; s <= sp; pc <= in; end
        3: begin m <= 4; mm <= 0; pc[15:8] <= in; end
        4: begin t <= MAIN; end
        endcase

    endcase

end

// -----------------------------------------------------------------------------
// АЛУ
// -----------------------------------------------------------------------------

// Выбор операндов
wire [7:0] op1 = dst == DST_A ? a  : (dst == DST_X ? x : (dst == DST_Y ? y : in));
wire [7:0] op2 = src == SRC_D ? in : (src == SRC_A ? a : (src == SRC_X ? x : y));

// Расчет результата
wire [8:0] alur =
    alu == ORA ? op1 | op2 :
    alu == AND ? op1 & op2 :
    alu == EOR ? op1 ^ op2 :
    alu == ADC ? op1 + op2 + p[CF] :
    alu == STA ? op1 :
    alu == LDA ? op2 :
    alu == BIT ? op1 & op2 :
    alu == CMP ? op1 - op2 :
    alu == SBC ? op1 - op2 - !p[CF] :
    alu == INC ? op1 + 1 :
    alu == DEC ? op1 - 1 :
    alu == ASL ? {op1[6:0], 1'b0} :
    alu == ROL ? {op1[6:0], p[CF]} :
    alu == LSR ? {1'b0,  op1[7:1]} :
    alu == ROR ? {p[CF], op1[7:1]} :
        8'hFF;

// Новые флаги после вычисления АЛУ
wire zf = alur[7:0] == 8'h00;
wire nf = alur[7];
wire cf = alur[8];
wire va = (op1[7] == op2[7]) & (op1[7] ^ alur[7]);
wire vs = (op1[7] != op2[7]) & (op1[7] ^ alur[7]);

wire [7:0] aluf =
    alu == ADC ? {nf, va,   p[5:2], zf,  cf} :
    alu == SBC ? {nf, vs,   p[5:2], zf, !cf} :
    alu == CMP ? {nf,       p[6:2], zf, !cf} :
    alu == BIT ? {op2[7:6], p[5:2], zf, p[CF]} :
    alu == ASL ||
    alu == ROL ? {nf,       p[6:2], zf, op1[7]} :
    alu == LSR ||
    alu == ROR ? {nf,       p[6:2], zf, op1[0]} :
                 {nf,       p[6:2], zf, p[CF]};

endmodule
