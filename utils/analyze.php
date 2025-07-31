<?php

$stat = [];
$f = fopen($argv[1], "r");
while ($s = trim(fgets($f))) {

    if (preg_match('~(\d+):([0-9a-f]{4}) ~i', $s, $c)) {

        $addr = hexdec($c[2]);
        $bank = $c[1];
        if ($addr >= 0xC000) $bank = 7;

        $pc = "$bank:{$c[2]}";

        if (!isset($stat[$pc])) {
            echo "$pc\n== $s\n";
        }

        $stat[$pc] = ($stat[$pc] ?? 0) + 1;
    }
}

fclose($f);
