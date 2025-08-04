module mapper
(
    input               clock,
    input               reset_n,
    input       [7:0]   num,            // Номер маппера
    input       [3:0]   max,            // Максимальное количество банков
    input               ce_cpu,
    input               ct_cpu,
    input       [15:0]  program_a,      // Адрес программы из PPU/CPU
    input       [15:0]  cpu_a,
    input       [ 7:0]  cpu_o,
    input               cpu_w,
    // --
    output reg          cw,
    output reg          cbank,
    output      [17:0]  program_m
);

reg [3:0] pbank;

assign program_m =

    // Если A >= C000, то BANK=MAX (последний), иначе номер выбранного банка (16K)
    num == 8'h02 ? {&program_a[15:14] ? max : pbank, program_a[13:0]} :
    // По умолчанию маппер NROM
    {pbank[2:0], program_a[14:0]};

always @(posedge clock)
if (reset_n == 0) begin

    cbank   <= 2'b00;
    cw      <= 1'b0;
    pbank   <= 3'b000;

end else begin

    case (num)

    // MAPPER2: PRG-ROM 256KB; CHR-RAM: 0KB
    8'h02: begin

        cw <= 1'b1;
        if (cpu_a[15] && cpu_w && ct_cpu) pbank <= cpu_o[3:0];

    end
    endcase

end

endmodule
