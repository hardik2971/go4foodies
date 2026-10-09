<?php

namespace App\Support;

use Carbon\Carbon;
use Carbon\CarbonInterface;

/**
 * Number / time formatting with the exact output of the Node admin
 * (admin/src/lib/utils.ts + the JS built-ins queries.ts relies on), so strings
 * in the API payloads are byte-identical to the Next.js backend.
 */
final class Format
{
    /**
     * Timezone that plays the role of the Node process's "server local time"
     * (new Date(y, m, d), getHours(), toLocaleTimeString()...). Defaults to the
     * app timezone (UTC); override with config('app.local_timezone').
     */
    public static function localTz(): string
    {
        return (string) (config('app.local_timezone') ?: config('app.timezone') ?: 'UTC');
    }

    /** "Now" in the server-local timezone. */
    public static function now(): Carbon
    {
        return Carbon::now(self::localTz());
    }

    /** A date converted to the server-local timezone (copy). */
    public static function local(CarbonInterface $d): Carbon
    {
        return Carbon::instance($d)->setTimezone(self::localTz());
    }

    /** Epoch milliseconds — JS Date#getTime(). */
    public static function ms(CarbonInterface $d): int
    {
        return (int) round($d->getPreciseTimestamp(3));
    }

    /** Format a number as USD currency, e.g. 15750 -> "$15,750" (Intl en-US, max 0 decimals). */
    public static function formatCurrency(float|int $value, int $maximumFractionDigits = 0, ?int $minimumFractionDigits = null): string
    {
        $min = $minimumFractionDigits ?? min(2, $maximumFractionDigits);
        $body = self::grouped(abs((float) $value), $maximumFractionDigits, $min);
        $negative = $value < 0 && $body !== self::grouped(0.0, $maximumFractionDigits, $min);

        return ($negative ? '-' : '').'$'.$body;
    }

    /** Compact number formatting, e.g. 5_000_000 -> "5M" (Intl compact, max 1 decimal). */
    public static function formatCompact(float|int $value): string
    {
        $abs = abs((float) $value);
        $units = ['', 'K', 'M', 'B', 'T'];
        $i = 0;
        while ($i < count($units) - 1 && $abs >= 1000 ** ($i + 1)) {
            $i++;
        }
        $scaled = round($abs / (1000 ** $i), 1);
        // Rounding up into the next magnitude (999_950 -> "1M").
        if ($scaled >= 1000 && $i < count($units) - 1) {
            $i++;
            $scaled = round($abs / (1000 ** $i), 1);
        }
        $body = self::grouped($scaled, 1, 0, '').$units[$i]; // compact notation never groups

        return ($value < 0 && $scaled != 0 ? '-' : '').$body;
    }

    /** Number#toLocaleString() for en-US (grouping, up to 3 fraction digits). */
    public static function locale(float|int $value): string
    {
        $body = self::grouped(abs((float) $value), 3, 0);

        return ($value < 0 && $body !== '0' ? '-' : '').$body;
    }

    /** String(number) as JS prints it: 5 -> "5", 2.5 -> "2.5", 0.1+0.2 -> "0.30000000000000004". */
    public static function js(float|int $value): string
    {
        if (is_int($value)) {
            return (string) $value;
        }
        if (is_nan($value)) {
            return 'NaN';
        }
        if (is_infinite($value)) {
            return $value > 0 ? 'Infinity' : '-Infinity';
        }
        if ($value == floor($value) && abs($value) < 1e21) {
            return number_format($value, 0, '.', '');
        }

        return (string) json_encode($value);
    }

    /** Date#toLocaleTimeString() (en-US) in server-local time, e.g. "3:51:01 PM". */
    public static function localeTime(CarbonInterface $d): string
    {
        return self::local($d)->format('g:i:s A');
    }

    /** JS Math.round (half rounds toward +Infinity). */
    public static function round(float|int $v): int|float
    {
        $r = floor($v + 0.5);

        return abs($r) < PHP_INT_MAX ? (int) $r : $r;
    }

    private static function grouped(float $abs, int $maxFrac, int $minFrac, string $sep = ','): string
    {
        $s = number_format($abs, $maxFrac, '.', $sep);
        if ($maxFrac > $minFrac && str_contains($s, '.')) {
            [$int, $frac] = explode('.', $s);
            $frac = rtrim($frac, '0');
            if (strlen($frac) < $minFrac) {
                $frac = str_pad($frac, $minFrac, '0');
            }
            $s = $frac === '' ? $int : $int.'.'.$frac;
        }

        return $s;
    }
}
