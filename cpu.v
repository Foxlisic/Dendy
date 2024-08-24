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

endmodule
