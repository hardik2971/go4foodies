<?php

namespace App\Support;

/** Collision-resistant ids in Prisma's cuid() shape: "c" + 24 base36 chars. */
final class Cuid
{
    private static int $counter = 0;

    public static function make(): string
    {
        $time = self::pad(base_convert((string) (int) floor(microtime(true) * 1000), 10, 36), 8);
        $count = self::pad(base_convert((string) (self::$counter++ % 1679616), 10, 36), 4);
        $finger = self::pad(base_convert((string) (getmypid() % 1679616), 10, 36), 4);
        $rand = '';
        for ($i = 0; $i < 2; $i++) {
            $rand .= self::pad(base_convert((string) random_int(0, 1679615), 10, 36), 4);
        }

        return 'c'.$time.$count.$finger.$rand;
    }

    private static function pad(string $s, int $n): string
    {
        return substr(str_pad($s, $n, '0', STR_PAD_LEFT), -$n);
    }
}
