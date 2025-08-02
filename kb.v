module kb
(
    // 25 MHZ
    input               clock,
    input               reset_n,

    // Рассылка команд
    input               cmd,            // =1 строб команды
    input       [7:0]   dat,            // Отсылаемый байт

    // Ввод-вывод на клавиатуру и наоборот
    inout               ps_clk,
    inout               ps_dat,

    // Исходящие данные от клавиатуры
    output  reg [7:0]   kbd,            // Данные от клавиатуры
    output  reg         hit,            // =1 Одиночный хит на получение данных от контроллера
    output  reg         err,            // =1 Ошибка обработки или таймаут
    output              ready           // =1 Устройство готово к приему команды cmd=1, dat
);

localparam
    PERIOD = 124,           // 100 kHz (25000000/100000/2 - 1)
    CWAIT  = 20;            // Ожидание перед отправкой команды x 5 мкс

localparam
    IDLE        = 0,
    RECEIVE     = 1,
    TRANSMIT    = 2;

assign ready  = (CMD == 0) && reset_n;
assign ps_clk = we_clk ? PS_CLK : 1'bz;
assign ps_dat = we_dat ? PS_DAT : 1'bz;

// 200 kHz делитель частоты (5 мкс один отсчет)
reg [ 1:0]  stage;
reg [ 7:0]  t;
reg [ 9:0]  dm;                 // Отсчет таймаута 5 мк x 1024 = 5 ms
reg [ 6:0]  dx;                 // 200 kHz
reg [ 1:0]  rt;                 // Обнаружение CLOCK
reg [ 3:0]  cnt;
reg         CMD;
reg [ 9:0]  DAT;
reg         we_clk, we_dat;
reg         PS_CLK, PS_DAT;

always @(negedge clock)
if (reset_n == 0) begin

    t       <= 0;
    dx      <= 0;
    dm      <= 0;
    we_clk  <= 0;
    we_dat  <= 0;
    cnt     <= 0;
    err     <= 0;
    stage   <= IDLE;
    CMD     <= 0;
    DAT     <= 8'h00;

end
else begin

    hit <= 0;

    // Регистрация команды для отсылки устройству
    if (cmd) begin CMD <= 1; DAT <= {/*STOP*/ 1'b1, /*PAR*/ ~^dat, dat}; err <= 0; end

    // 5 микросекунд, 200 kHz (основано на 25 Mhz) 25M / 125 = 200k
    if (dx == PERIOD) begin

        // Регистрация сигнала CLK от клавиатуры
        rt <= {rt[0], ps_clk};

        // Проверка на таймаут, сброс в IDLE при ошибке
        if (stage) begin dm <= dm + 1; if (&dm) begin stage <= IDLE; CMD <= 0; err <= 1; end end

        case (stage)

            // Ожидание команды от хоста или данных от клавиатуры/мыши
            // -----------------------------------------------------------------
            IDLE: begin

                t   <= 0;
                cnt <= 0;

                // [R] Получен сигнал от клавиатуры
                if (rt == 2'b10) begin

                    stage <= RECEIVE;
                    err   <= 0;

                end
                // [T] Запрос исполнения команды
                else if (CMD) begin

                    stage <= TRANSMIT;
                    err   <= 0;
                    {we_clk, we_dat} <= 2'b11;
                    {PS_CLK, PS_DAT} <= 2'b11;

                end

            end

            // Прием сигнала от устройства
            // https://ru.wikipedia.org/wiki/Скан-код
            // -----------------------------------------------------------------
            RECEIVE: if (rt == 2'b01) begin

                t  <= t + 1;
                dm <= 0;

                case (t)
                // Старт-бит должен быть равен 0, иначе не принимать данные
                0: if (ps_dat) begin stage <= IDLE; err <= 1; end

                // Прием LSB (8 бит)
                1,2,3,4,5,6,7,8: kbd <= {ps_dat, kbd[7:1]};

                // Сверка бита четности:
                // - Если количество ЧЕТНО, то там будет 0, а в PS_DAT=1, так что ОК
                // - И наоборот также, НЕЧЕТНО дает 1, а в PS_DAT=0, и это OK
                // - Иначе не OK ни разу
                9: begin hit <= ps_dat ^ (^kbd); end

                // Стоповый бит если 0, то это ошибка
                10: begin stage <= IDLE; err <= ~ps_dat; CMD <= 0; end
                endcase

            end

            // Процедура отсылки команды на клавиатуру
            // https://wiki.osdev.org/PS/2_Keyboard#Command_Queue_and_State_Machine
            // -----------------------------------------------------------------
            TRANSMIT: begin

                t <= t + 1;

                case (t)

                    // Пролог
                    CWAIT:    begin PS_CLK <= 0; end              // CLK=0 на 100 мк
                    CWAIT+20: begin PS_DAT <= 0; end              // DAT=0 на 50 мк
                    CWAIT+28: begin PS_CLK <= 1; end              // CLK=1 старт бит
                    CWAIT+29: begin we_clk <= 0; dm <= 0; end

                    // Ожидание 10 битов от клавиатуры
                    // Ожидание может длиться до 5 миллисекунд, иначе сброс
                    CWAIT+30: begin

                        t <= CWAIT+30;

                        // На негативном фронте CLK отправка данных
                        if (rt == 2'b10) begin

                            PS_DAT  <= DAT[0];
                            DAT     <= DAT[9:1];
                            cnt     <= cnt + 1;
                            dm      <= 0;

                        end
                        // Отосланы все 10 бит, на позитивном фронте CLK
                        else if (rt == 2'b01 && cnt == 10) t <= CWAIT+31;

                    end

                    // Ждать бита ACK от клавиатуры
                    CWAIT+31: we_dat <= 0;
                    CWAIT+33: begin dm <= 0; t <= CWAIT + (rt == 2'b01 ? 34 : 33); end

                    // Через 10 мкс завершить отсылку и перейти к стадии приема ответа от клавиатуры
                    CWAIT+34: t <= (rt == 2'b10) ? CWAIT+35 : CWAIT+34;
                    CWAIT+35: begin stage <= RECEIVE; t <= 0; end

                endcase

            end

        endcase

    end

    dx <= (dx == PERIOD) ? 0 : dx + 1;

end

endmodule