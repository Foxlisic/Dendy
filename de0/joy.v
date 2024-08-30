module joy
(
    input               clock,  // 25 MHZ (40 ns)
    input               pin_d1, // UP    :: UP    :: Z
    input               pin_d2, // DOWN  :: DOWN  :: Y
    input               pin_d3, // LEFT  ::       :: X
    input               pin_d4, // RIGHT ::       :: MODE
    input               pin_d6, // B     :: A     :: --
    output reg          pin_d7, // (H)      (L)      (3HL)
    input               pin_d9, // C     :: START :: --
    output reg [11:0]   joy     // XYZMC|RLDUVSAB
);

reg [8:0] t;
reg [3:0] i;

// 20 ms интервал. Обязательно точное значение!
always @(posedge clock)
if (t == 499) begin

    // 16 x 20 = 320 мкс обновление
    case (i)
    0:   begin pin_d7 <= 1'b1; end
    1:   begin pin_d7 <= 1'b0; {joy[8:4], joy[0]} <= {/*C*/  pin_d9, /*R*/ pin_d4, /*L*/ pin_d3, /*D*/ pin_d2, /*U*/ pin_d1, /*B*/ pin_d6}; end
    2:   begin pin_d7 <= 1'b1; {joy[3],   joy[1]} <= {/*ST*/ pin_d9, /*A*/ pin_d6}; end
    3,5: begin pin_d7 <= 1'b0; end
    4,6: begin pin_d7 <= 1'b1; end
    7:   begin pin_d7 <= 1'b0; {joy[11:9], joy[2]} <= {pin_d3, pin_d2, pin_d1, /*M*/ pin_d4}; end
    8:   begin pin_d7 <= 1'b1; end
    endcase

    i <= i + 1;
    t <= 0;

end else t <= t + 1;

endmodule
