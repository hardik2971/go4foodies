<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** /floor — port of app/(dashboard)/floor/page.tsx + components/floor/FloorPlan.tsx */
class FloorController extends Controller
{
    /** floor-data.ts TABLE_STATES */
    public const STATES = ['AVAILABLE', 'RESERVED', 'OCCUPIED', 'WAITING_PAYMENT', 'CLEANING', 'OUT_OF_SERVICE'];

    /** floor-data.ts PAYMENT_METHODS */
    public const PAYMENT_METHODS = ['Cash', 'Credit Card', 'Debit Card', 'UPI', 'Wallet', 'Mixed'];

    public function index()
    {
        return view('floor.index', [
            'tables' => $this->tables(),
            'waiters' => $this->safe(fn () => Queries::getWaiterOptions()),
            'paymentMethods' => self::PAYMENT_METHODS,
            'states' => self::STATES,
        ]);
    }

    /** router.refresh() equivalent — fresh table states for the live floor. */
    public function data(): JsonResponse
    {
        return response()->json(['tables' => $this->tables()]);
    }

    /**
     * Cheap change token for live polling (stands in for the /api/floor-stream SSE,
     * which would block `php artisan serve`'s single worker). Changes whenever a
     * table, session, order or payment is created/updated/deleted.
     */
    public function version(): JsonResponse
    {
        $parts = [];
        foreach (['Table', 'TableSession', 'Order'] as $t) {
            $row = DB::table($t)->selectRaw('MAX(`updatedAt`) AS m, COUNT(*) AS c')->first();
            $parts[] = ($row->m ?? '').'#'.($row->c ?? 0);
        }
        $parts[] = (string) DB::table('Payment')->count();

        return response()->json(['v' => implode('|', $parts)]);
    }

    /** "Open & seat" →openTableSession(tableId, {customerCount, waiterId?, customerName?}) */
    public function open(Request $request, string $tableId): JsonResponse
    {
        Actions::openTableSession($tableId, self::openInput($request));

        return response()->json(['ok' => true, 'tables' => $this->tables()]);
    }

    /** "Close table" → closeTableSession(sessionId, {paymentMethod}) */
    public function close(Request $request, string $sessionId): JsonResponse
    {
        $data = $request->validate(['paymentMethod' => ['nullable', 'string', 'max:50']]);
        Actions::closeTableSession($sessionId, ['paymentMethod' => $data['paymentMethod'] ?? 'Cash']);

        return response()->json(['ok' => true, 'tables' => $this->tables()]);
    }

    /** "Set state" chips → setTableState(tableId, state) */
    public function state(Request $request, string $tableId): JsonResponse
    {
        $data = $request->validate(['state' => ['required', Rule::in(self::STATES)]]);
        Actions::setTableState($tableId, $data['state']);

        return response()->json(['ok' => true]);
    }

    /** Shared with the POS "Open table" form. */
    public static function openInput(Request $request): array
    {
        $data = $request->validate([
            'customerCount' => ['required', 'integer', 'min:1'],
            'waiterId' => ['nullable', 'string'],
            'customerName' => ['nullable', 'string', 'max:120'],
        ]);

        return array_filter([
            'customerCount' => (int) $data['customerCount'],
            'waiterId' => $data['waiterId'] ?? null ?: null,
            'customerName' => $data['customerName'] ?? null ?: null,
        ], fn ($v) => $v !== null);
    }

    private function tables(): array
    {
        return $this->safe(fn () => Queries::getFloorTables());
    }

    private function safe(callable $fn): array
    {
        try {
            return $fn();
        } catch (\Throwable $e) {
            report($e);

            return [];
        }
    }
}
