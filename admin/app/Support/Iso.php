<?php

namespace App\Support;

use Carbon\Carbon;
use DateTimeInterface;

/** JS Date#toISOString() format ("2026-10-08T14:03:00.000Z") — the API date contract. */
final class Iso
{
    public static function of(DateTimeInterface|string|null $d): ?string
    {
        if ($d === null || $d === '') {
            return null;
        }

        return Carbon::parse($d)->utc()->format('Y-m-d\TH:i:s.v\Z');
    }

    /** "YYYY-MM-DD" (UTC) — same as `iso.slice(0, 10)`. */
    public static function date(DateTimeInterface|string|null $d): ?string
    {
        return $d === null ? null : Carbon::parse($d)->utc()->format('Y-m-d');
    }
}
