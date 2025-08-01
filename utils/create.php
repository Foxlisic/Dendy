<?php

switch ($argv[1])
{
    // Подготовка MIF-файлов
    case 'nes':

        $in      = $argv[2];
        $mif_prg = $argv[3] ?? "mif_prg.mif";
        $mif_chr = $argv[4] ?? "mif_chr.mif";
        $opts    = $argv[5] ?? "";
        // ----------
        $data    = file_get_contents($in);
        $prg_num = ord($data[4]);
        $chr_num = ord($data[5]);

        $program = substr($data, 16,  $prg_num * 16384);
        $chardat = substr($data, 16 + $prg_num * 16384, $chr_num * 8192);

        // Удвоение 16K -> 32K
        if ($opts == '16k') { $program = $program.$program; $prg_num = 2; }

        file_put_contents($mif_prg, create_mif($program, $prg_num * 16384));
        file_put_contents($mif_chr, create_mif($chardat, $chr_num * 8192));
        break;

    // Сбор в мультиигровку
    case 'multi':

        $PRG = 0; $program = '';
        $CHR = 0; $chrdata = '';

        foreach (array_slice($argv, 2) as $rom) {

            $file    = glob("$rom*.nes")[0];
            $data    = file_get_contents($file);
            $prg_num = ord($data[4]);
            $chr_num = ord($data[5]);

            // Прочесть программу и данные
            $program .= substr($data, 16,  $prg_num * 16384);
            $chrdata .= substr($data, 16 + $prg_num * 16384, $chr_num * 8192);

            // Для информации, где и что лежит
            echo "[$rom] PRG=$PRG CHR=$CHR SIZE=".($prg_num - 1)." ".basename($file)."\n";

            $PRG += $prg_num;
            $CHR += $chr_num;
        }

        file_put_contents("c5/mif_prg.mif", create_mif($program, $PRG * 16384));
        file_put_contents("c5/mif_chr.mif", create_mif($chrdata, $CHR * 8192));

        break;

    // Для тестов DE0
    case 'test':

        $in      = $argv[2];
        $data    = file_get_contents(glob("$in*.nes")[0]);
        $video   = file_get_contents(glob("$in*video.bin")[0]);
        $oamdata = file_get_contents(glob("$in*oam.bin")[0]);
        $prg_num = ord($data[4]);

        $program = substr($data, 16, $prg_num * 16384);
        $charctr = substr($video, 0, 8192);
        $chardat = substr($video, 8192, 2048);

        file_put_contents("c5/mif_chr.mif", create_mif($charctr, 8192));
        file_put_contents("c5/mif_oam.mif", create_mif($oamdata));
        file_put_contents("c5/mif_vrm.mif", create_mif($chardat));

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
