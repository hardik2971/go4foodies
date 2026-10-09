<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** /pos/{tableId} — port of app/(dashboard)/pos/[tableId]/page.tsx + components/pos/PosScreen.tsx */
class PosController extends Controller
{
    public function show(string $tableId)
    {
        $pos = Queries::getTablePos($tableId);
        abort_if(empty($pos['table']), 404);

        return view('pos.show', [
            'table' => $pos['table'],
            'session' => $pos['session'] ?? null,
            'menu' => $this->safe(fn () => Queries::getMenuItems()),
            'waiters' => $this->safe(fn () => Queries::getWaiterOptions()),
            'mergeTargets' => $this->safe(fn () => Queries::getMergeTargets($tableId)),
            'paymentMethods' => FloorController::PAYMENT_METHODS,
        ]);
    }

    /** router.refresh() equivalent: the live table/session after a mutation. */
    public function data(string $tableId): JsonResponse
    {
        return response()->json($this->payload($tableId));
    }

    /** Open-table form (no session yet) → openTableSession */
    public function open(Request $request, string $tableId): JsonResponse
    {
        Actions::openTableSession($tableId, FloorController::openInput($request));

        return response()->json($this->payload($tableId));
    }

    /** Send to kitchen (KOT) / "+" on a bill line → addSessionOrder(sessionId, items) */
    public function addOrder(Request $request, string $sessionId): JsonResponse
    {
        $data = $request->validate([
            'tableId' => ['required', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.menuItemId' => ['required', 'string'],
            'items.*.qty' => ['required', 'integer', 'min:1'],
        ]);
        Actions::addSessionOrder($sessionId, array_map(
            fn ($i) => ['menuItemId' => $i['menuItemId'], 'qty' => (int) $i['qty']],
            array_values($data['items']),
        ));

        return response()->json($this->payload($data['tableId']));
    }

    /** "−" on a bill line (void one unit) → decrementSessionItem(sessionId, menuItemId) */
    public function decrement(Request $request, string $sessionId): JsonResponse
    {
        $data = $request->validate(['tableId' => ['required', 'string'], 'menuItemId' => ['required', 'string']]);
        Actions::decrementSessionItem($sessionId, $data['menuItemId']);

        return response()->json($this->payload($data['tableId']));
    }

    /** "Save adjustments" → updateSessionBilling(sessionId, {discount, tax, serviceCharge, tip}) */
    public function billing(Request $request, string $sessionId): JsonResponse
    {
        Actions::updateSessionBilling($sessionId, $this->billingInput($request));

        return response()->json($this->payload($request->input('tableId')));
    }

    /** "Merge" → mergeSessions(fromSessionId, intoSessionId) */
    public function merge(Request $request, string $sessionId): JsonResponse
    {
        $data = $request->validate(['tableId' => ['required', 'string'], 'fromSessionId' => ['required', 'string']]);
        Actions::mergeSessions($data['fromSessionId'], $sessionId);

        return response()->json($this->payload($data['tableId']));
    }

    /** Split / partial payment → addPayment(sessionId, {amount, method}) */
    public function payment(Request $request, string $sessionId): JsonResponse
    {
        $data = $request->validate([
            'tableId' => ['required', 'string'],
            'amount' => ['required', 'numeric', 'gt:0'],
            'method' => ['required', 'string', 'max:50'],
        ]);
        Actions::addPayment($sessionId, ['amount' => (float) $data['amount'], 'method' => $data['method']]);

        return response()->json($this->payload($data['tableId']));
    }

    /** Close & Pay → updateSessionBilling + closeTableSession, then back to the floor. */
    public function close(Request $request, string $sessionId): JsonResponse
    {
        $billing = $this->billingInput($request);
        $data = $request->validate(['paymentMethod' => ['nullable', 'string', 'max:50']]);
        Actions::updateSessionBilling($sessionId, $billing);
        Actions::closeTableSession($sessionId, ['paymentMethod' => $data['paymentMethod'] ?? 'Cash']);

        return response()->json(['ok' => true, 'redirect' => '/floor']);
    }

    private function billingInput(Request $request): array
    {
        $data = $request->validate([
            'discount' => ['required', 'numeric'],
            'tax' => ['required', 'numeric'],
            'serviceCharge' => ['required', 'numeric'],
            'tip' => ['required', 'numeric'],
        ]);

        return array_map(fn ($v) => (float) $v, $data);
    }

    private function payload(?string $tableId): array
    {
        $pos = $tableId ? Queries::getTablePos($tableId) : ['table' => null, 'session' => null];

        return [
            'ok' => true,
            'table' => $pos['table'] ?? null,
            'session' => $pos['session'] ?? null,
            'mergeTargets' => $tableId ? $this->safe(fn () => Queries::getMergeTargets($tableId)) : [],
        ];
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
