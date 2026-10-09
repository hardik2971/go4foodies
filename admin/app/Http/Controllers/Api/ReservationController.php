<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Body;
use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\Schemas;
use App\Http\Controllers\Api\Support\Z;
use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Reservation;
use App\Services\Mailer;
use App\Services\Scheduling;
use App\Support\Format;
use App\Support\Iso;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** /api/reservations (+ /availability) — port of app/api/reservations/**. */
class ReservationController extends Controller
{
    /** GET /api/reservations — list (newest first), raw rows. */
    public function index()
    {
        try {
            $rows = DB::table('Reservation')->orderByDesc('createdAt')->get()
                ->map(fn ($r) => Json::row($r, ['date' => 'date', 'guests' => 'int', 'createdAt' => 'date', 'updatedAt' => 'date']))
                ->all();

            return Json::response(['reservations' => $rows]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Database unavailable', 503);
        }
    }

    /** `new Date("YYYY-MM-DDT00:00:00")` / `T23:59:59` — server-local day bounds as UTC. */
    public static function dayBounds(string $date): array
    {
        $tz = Format::localTz();
        try {
            $start = Carbon::parse("{$date} 00:00:00", $tz)->utc();
            $end = Carbon::parse("{$date} 23:59:59", $tz)->utc();
        } catch (\Throwable) {
            throw new \RuntimeException('Invalid date');
        }

        return [$start, $end];
    }

    /** `new Date(str)` — date-only strings are UTC midnight, date-times are local. */
    public static function jsDate(string $s): Carbon
    {
        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $s)) {
            return Carbon::parse($s.' 00:00:00', 'UTC');
        }
        if (preg_match('/(Z|[+-]\d{2}:?\d{2})$/i', $s)) {
            return Carbon::parse($s)->utc();
        }

        return Carbon::parse($s, Format::localTz())->utc();
    }

    /** GET /api/reservations/availability?date=YYYY-MM-DD */
    public function availability(Request $req)
    {
        $date = $req->query('date');
        if (! is_string($date) || ! preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            return Json::error('A valid date (YYYY-MM-DD) is required', 400);
        }

        try {
            [$dayStart, $dayEnd] = self::dayBounds($date);
            $taken = DB::table('Reservation')
                ->where('kind', 'TABLE')
                ->whereBetween('date', [$dayStart->format('Y-m-d H:i:s.v'), $dayEnd->format('Y-m-d H:i:s.v')])
                ->whereNotIn('status', ['CANCELED', 'NO_SHOW'])
                ->whereNotNull('time')
                ->pluck('time');

            $used = [];
            foreach ($taken as $t) {
                if ($t) {
                    $used[$t] = ($used[$t] ?? 0) + 1;
                }
            }

            $now = (int) floor(microtime(true) * 1000);
            $slots = array_map(function ($time) use ($used, $date, $now) {
                $u = $used[$time] ?? 0;
                $when = Scheduling::slotDateTime($date, $time);
                $pastCutoff = $when ? Format::ms($when) < $now + Scheduling::LEAD_MINUTES * 60000 : true;
                $remaining = max(0, Scheduling::SLOT_CAPACITY - $u);

                return ['time' => $time, 'available' => $remaining > 0 && ! $pastCutoff, 'remaining' => $remaining];
            }, Scheduling::allSlots());

            return Json::response(['date' => $date, 'slots' => $slots]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Availability unavailable', 503);
        }
    }

    /** POST /api/reservations — the public site's ReservationFlow submits here. */
    public function store(Request $req)
    {
        return self::create(Body::json($req));
    }

    /** Shared with the Customer app (/api/mobile/customer/reservations). */
    public static function create(mixed $body)
    {
        [$data, $issues] = Z::safeParse(Schemas::reservation(), $body);
        if ($issues) {
            return Json::error('Invalid payload', 400, ['issues' => $issues]);
        }

        $prefix = $data['kind'] === 'PRIVATE_EVENT' ? 'EV' : 'SV';
        $reference = $prefix.'-'.random_int(100000, 999999);

        // Dine-in (TABLE) bookings get slot + double-booking validation.
        if ($data['kind'] === 'TABLE') {
            $check = Scheduling::validateSlot($data['date'], $data['time']);
            if (! $check['ok']) {
                return Json::error($check['reason'], 422);
            }
        }

        try {
            if ($data['kind'] === 'TABLE') {
                [$dayStart, $dayEnd] = self::dayBounds($data['date']);
                $taken = DB::table('Reservation')
                    ->where('kind', 'TABLE')
                    ->where('time', $data['time'])
                    ->whereBetween('date', [$dayStart->format('Y-m-d H:i:s.v'), $dayEnd->format('Y-m-d H:i:s.v')])
                    ->whereNotIn('status', ['CANCELED', 'NO_SHOW'])
                    ->count();
                if ($taken >= Scheduling::SLOT_CAPACITY) {
                    return Json::error('That time slot is fully booked — please choose another.', 409);
                }
            }

            // Link/create a customer record by email so reservations roll up into CRM.
            $customer = Customer::where('email', $data['email'])->first();
            if ($customer) {
                $customer->fill(['name' => $data['name'], 'phone' => $data['phone']]);
                $customer->updatedAt = now();
                $customer->save();
            } else {
                $customer = Customer::create(['name' => $data['name'], 'email' => $data['email'], 'phone' => $data['phone']]);
            }

            $fields = $data['kind'] === 'TABLE'
                ? ['time' => $data['time'], 'guests' => $data['guests'], 'occasion' => $data['occasion'] ?? null, 'requests' => $data['requests'] ?? null]
                : ['eventType' => $data['eventType'], 'guestRange' => $data['guestRange'], 'space' => $data['space'],
                    'company' => $data['company'] ?? null, 'message' => $data['message'] ?? null];

            $reservation = Reservation::create([
                'reference' => $reference,
                'kind' => $data['kind'],
                'date' => self::jsDate($data['date']),
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'],
                'customerId' => $customer->id,
            ] + $fields);

            // Branded confirmation email — never fail the booking if mail/SMTP errors.
            try {
                $dateLabel = Carbon::parse($data['date'].' 00:00:00', Format::localTz())->format('D, M j, Y');
                $mail = Mailer::reservationConfirmationEmail(array_filter([
                    'reference' => $reference,
                    'name' => $data['name'],
                    'kind' => $data['kind'],
                    'dateLabel' => $dateLabel,
                ] + ($data['kind'] === 'TABLE'
                    ? ['time' => $data['time'], 'guests' => $data['guests'], 'occasion' => $data['occasion'] ?? null, 'requests' => $data['requests'] ?? null]
                    : ['eventType' => $data['eventType'], 'guestRange' => $data['guestRange'], 'space' => $data['space'], 'message' => $data['message'] ?? null]),
                    fn ($v) => $v !== null));
                Mailer::sendMail(['to' => $data['email'], 'subject' => $mail['subject'], 'html' => $mail['html'], 'text' => $mail['text']]);
            } catch (\Throwable $mailErr) {
                report($mailErr);
            }

            return Json::response(['reference' => $reference, 'id' => $reservation->id], 201);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Database unavailable', 503);
        }
    }

    /** Reservation → the Customer app view (customer/[...path] reservationView). */
    public static function view(object $r): array
    {
        $u = fn ($v) => $v ?? null;

        return array_filter([
            'id' => $r->id,
            'reference' => $r->reference,
            'kind' => $r->kind,
            'status' => $r->status,
            'date' => Iso::of($r->date),
            'time' => $u($r->time),
            'guests' => $r->guests === null ? null : (int) $r->guests,
            'occasion' => $u($r->occasion),
            'requests' => $u($r->requests),
            'eventType' => $u($r->eventType),
            'guestRange' => $u($r->guestRange),
            'space' => $u($r->space),
            'company' => $u($r->company),
            'message' => $u($r->message),
            'createdAt' => Iso::of($r->createdAt),
        ], fn ($v) => $v !== null); // `?? undefined` keys are dropped by JSON.stringify
    }
}
