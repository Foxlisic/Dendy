<?php

switch ($argv[1])
{
    // Для тестов DE0
    case 'nes':

        $in      = $argv[2];
        $data    = file_get_contents(glob("$in*.nes")[0]);
        $video   = file_get_contents(glob("$in*video.bin")[0]);
        $oamdata = file_get_contents(glob("$in*oam.bin")[0]);
        $prg_num = ord($data[4]);

        $program = substr($data, 16, $prg_num * 16384);
        $charctr = substr($video, 0, 8192);
        $chardat = substr($video, 8192, 2048);

        file_put_contents("de0/mem_chr.mif", create_mif($charctr, 8192));
        file_put_contents("de0/mem_oam.mif", create_mif($oamdata));
        file_put_contents("de0/mem_vrm.mif", create_mif($chardat));

        break;
}

/*
 * Конвертирование из Bin -> MIF файл
 * Аргумент 1: Размер памяти (256k = 262144)
 * Аргумент 2: bin-файл
 * Аргумент 3: Куда выгрузить
 */
function create_mif($data, $size = 0)
{
    $len = strlen($data);
    if ($size == 0) $size = strlen($data);

    if (empty($size)) { echo "size required\n"; exit(1); }

    $out = [
        "WIDTH=8;",
        "DEPTH=$size;",
        "ADDRESS_RADIX=HEX;",
        "DATA_RADIX=HEX;",
        "CONTENT BEGIN",
    ];

    $a = 0;

    // RLE-кодирование
    while ($a < $len) {

        // Поиск однотонных блоков
        for ($b = $a + 1; $b < $len && $data[$a] == $data[$b]; $b++);

        // Если найденный блок длиной до 0 до 2 одинаковых символов
        if ($b - $a < 3) {
            for ($i = $a; $i < $b; $i++) $out[] = sprintf("  %X: %02X;", $a++, ord($data[$i]));
        } else {
            $out[] = sprintf("  [%X..%X]: %02X;", $a, $b - 1, ord($data[$a]));
            $a = $b;
        }
    }

    if ($len < $size) $out[] = sprintf("  [%X..%X]: 00;", $len, $size-1);
    $out[] = "END;";

    return join("\n", $out);
}
