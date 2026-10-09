<?php

namespace App\Services;

use App\Support\Format;
use Carbon\Carbon;
use Carbon\CarbonInterface;

/**
 * Scheduling rules for online ordering & dine-in reservations (TASK 1) — port of
 * admin/src/lib/scheduling.ts. Server-side authority for business hours,
 * cutoff and pickup estimates. The website mirrors this config in
 * `website/lib/order.ts` for the UI — keep the two in sync if hours change.
 *
 * Timezone: scheduling.ts builds slot times with `new Date(y, m, d, h, mm)`,
 * i.e. in the Node process's local timezone. Here "server local time" is
 * Format::localTz() — the app timezone (UTC) unless config('app.local_timezone')
 * is set — so a "18:30" slot is 18:30 in that zone.
 */
final class Scheduling
{
    public const BUSINESS_HOURS = [
        'openHour' => 10, // first slot 10:00
        'closeHour' => 22, // kitchen closes 22:00 → last slot 21:30
        'slotMinutes' => 30,
    ];

    /** Minutes a guest must book ahead of a slot ("cutoff time"). */
    public const LEAD_MINUTES = 30;

    /** Default prep time used to estimate an ASAP take-away pickup. */
    public const PREP_MINUTES = 25;

    /** Max simultaneous dine-in reservations per 30-min slot (double-booking guard). */
    public const SLOT_CAPACITY = 6;

    /**
     * All bookable "HH:mm" slots for a service day.
     *
     * @return string[]
     */
    public static function allSlots(): array
    {
        $slots = [];
        ['openHour' => $open, 'closeHour' => $close, 'slotMinutes' => $step] = self::BUSINESS_HOURS;
        for ($m = $open * 60; $m < $close * 60; $m += $step) {
            $slots[] = sprintf('%02d:%02d', intdiv($m, 60), $m % 60);
        }

        return $slots;
    }

    /**
     * Combine a "YYYY-MM-DD" date and "HH:mm" time into a date (server local
     * time). Out-of-range parts roll over exactly like the JS Date constructor.
     */
    public static function slotDateTime(string $date, string $time): ?Carbon
    {
        if (! preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $date, $m) || ! preg_match('/^(\d{1,2}):(\d{2})$/', $time, $t)) {
            return null;
        }
        $d = Carbon::now(Format::localTz())
            ->setDate((int) $m[1], (int) $m[2], (int) $m[3])
            ->setTime((int) $t[1], (int) $t[2], 0, 0);

        return $d;
    }

    /**
     * Validate a scheduled date+time: real slot, within hours, past the cutoff.
     *
     * @return array{ok:bool, reason:?string}
     */
    public static function validateSlot(string $date, string $time, ?CarbonInterface $now = null): array
    {
        $now ??= Carbon::now();
        if (! in_array($time, self::allSlots(), true)) {
            return ['ok' => false, 'reason' => 'Outside business hours'];
        }
        $when = self::slotDateTime($date, $time);
        if (! $when) {
            return ['ok' => false, 'reason' => 'Invalid date or time'];
        }
        if (Format::ms($when) < Format::ms($now) + self::LEAD_MINUTES * 60_000) {
            return ['ok' => false, 'reason' => 'That time is too soon — please pick a later slot'];
        }

        return ['ok' => true, 'reason' => null];
    }

    /** Estimated pickup time for a take-away order ('NOW' | 'LATER'). */
    public static function estimatePickup(string $scheduleType, ?string $date = null, ?string $time = null, ?CarbonInterface $now = null): Carbon
    {
        $now = Carbon::instance($now ?? Carbon::now());
        if ($scheduleType === 'LATER' && $date && $time) {
            return self::slotDateTime($date, $time) ?? $now->copy()->addMinutes(self::PREP_MINUTES);
        }

        return $now->copy()->addMinutes(self::PREP_MINUTES);
    }
}
