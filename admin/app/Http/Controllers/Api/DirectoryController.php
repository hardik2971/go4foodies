<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Body;
use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\Z;
use App\Http\Controllers\Controller;
use App\Models\Employee;
use App\Models\Outlet;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Raw-row list/create endpoints, ported as-is (no auth, Prisma row shapes):
 * GET /api/customers · GET+POST /api/staff · GET+POST /api/outlets.
 *
 * Deliberate difference: the Next.js versions also return the `password` (bcrypt hash)
 * column of Customer / Employee rows to unauthenticated callers; it is omitted here.
 */
class DirectoryController extends Controller
{
    private const HIDDEN = ['password'];

    /** GET /api/customers — customers with their orders + reservations (name asc). */
    public function customers()
    {
        try {
            $customers = DB::table('Customer')->orderBy('name')->get();
            $ids = $customers->pluck('id')->all();
            $orders = DB::table('Order')->whereIn('customerId', $ids)->orderBy('id')
                ->get(['customerId', 'number', 'total', 'status', 'createdAt'])->groupBy('customerId');
            $reservations = DB::table('Reservation')->whereIn('customerId', $ids)->orderBy('id')
                ->get(['customerId', 'reference', 'kind', 'status', 'date'])->groupBy('customerId');

            $out = $customers->map(function ($c) use ($orders, $reservations) {
                $row = Json::row($c, ['createdAt' => 'date', 'updatedAt' => 'date'], self::HIDDEN);
                $row['orders'] = ($orders[$c->id] ?? collect())->map(fn ($o) => [
                    'number' => $o->number,
                    'total' => Json::decimal($o->total),
                    'status' => $o->status,
                    'createdAt' => \App\Support\Iso::of($o->createdAt),
                ])->values()->all();
                $row['reservations'] = ($reservations[$c->id] ?? collect())->map(fn ($r) => [
                    'reference' => $r->reference,
                    'kind' => $r->kind,
                    'status' => $r->status,
                    'date' => \App\Support\Iso::of($r->date),
                ])->values()->all();

                return $row;
            })->all();

            return Json::response(['customers' => $out]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Database unavailable', 503);
        }
    }

    private const EMPLOYEE_TYPES = ['active' => 'bool', 'createdAt' => 'date'];

    /** GET /api/staff — employee directory. */
    public function staff()
    {
        try {
            $rows = DB::table('Employee')->orderBy('name')->get()
                ->map(fn ($e) => Json::row($e, self::EMPLOYEE_TYPES, self::HIDDEN))->all();

            return Json::response(['employees' => $rows]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Database unavailable', 503);
        }
    }

    /** POST /api/staff — add an employee. */
    public function createStaff(Request $req)
    {
        [$data, $issues] = Z::safeParse(Z::object([
            'name' => Z::string(['min' => [2]]),
            'role' => Z::string(['min' => [1]]),
            'outletId' => Z::string(['min' => [1]]),
            'email' => Z::optional(Z::string(['email' => null])),
            'phone' => Z::optional(Z::string()),
            'status' => Z::default(Z::enum(['ON_DUTY', 'ON_BREAK', 'ABSENT', 'OFF']), 'OFF'),
        ]), Body::json($req));
        if ($issues) {
            return Json::error('Invalid payload', 400, ['issues' => $issues]);
        }
        try {
            $e = Employee::create($data);
            $row = DB::table('Employee')->where('id', $e->id)->first();

            return Json::response(['employee' => Json::row($row, self::EMPLOYEE_TYPES, self::HIDDEN)], 201);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Database unavailable', 503);
        }
    }

    private const OUTLET_TYPES = ['isActive' => 'bool', 'createdAt' => 'date'];

    /** GET /api/outlets — outlets with their metrics (periodStart asc). */
    public function outlets()
    {
        try {
            $outlets = DB::table('Outlet')->orderBy('name')->get();
            $metrics = DB::table('OutletMetric')->whereIn('outletId', $outlets->pluck('id')->all())
                ->orderBy('periodStart')->get()->groupBy('outletId');
            $out = $outlets->map(function ($o) use ($metrics) {
                $row = Json::row($o, self::OUTLET_TYPES);
                $row['metrics'] = ($metrics[$o->id] ?? collect())
                    ->map(fn ($m) => Json::row($m, ['periodStart' => 'date', 'revenue' => 'dec', 'operationalCost' => 'dec']))
                    ->values()->all();

                return $row;
            })->all();

            return Json::response(['outlets' => $out]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Database unavailable', 503);
        }
    }

    /** POST /api/outlets — create an outlet. */
    public function createOutlet(Request $req)
    {
        [$data, $issues] = Z::safeParse(Z::object([
            'name' => Z::string(['min' => [1]]),
            'location' => Z::optional(Z::string()),
            'address' => Z::optional(Z::string()),
            'phone' => Z::optional(Z::string()),
            'manager' => Z::optional(Z::string()),
            'isActive' => Z::default(Z::boolean(), true),
        ]), Body::json($req));
        if ($issues) {
            return Json::error('Invalid payload', 400, ['issues' => $issues]);
        }
        try {
            $o = Outlet::create($data);
            $row = DB::table('Outlet')->where('id', $o->id)->first();

            return Json::response(['outlet' => Json::row($row, self::OUTLET_TYPES)], 201);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Database unavailable', 503);
        }
    }
}
