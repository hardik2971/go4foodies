<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** /reservations — port of app/(dashboard)/reservations/page.tsx + components/reservations/* */
class ReservationController extends Controller
{
    public const STATUSES = ['REQUESTED', 'CONFIRMED', 'SEATED', 'COMPLETED', 'CANCELED', 'NO_SHOW'];

    public function index()
    {
        try {
            $reservations = Queries::getReservations();
        } catch (\Throwable $e) {
            report($e);
            $reservations = [];
        }

        return view('reservations.index', ['reservations' => $reservations]);
    }

    /** ReservationDetail "Mark …" → setReservationStatus(id, status) */
    public function status(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::in(self::STATUSES)]]);
        Actions::setReservationStatus($id, $data['status']);

        return response()->json(['ok' => true]);
    }

    /** ReservationDetail edit form → updateReservation(id, ReservationEdit) */
    public function update(Request $request, string $id): JsonResponse
    {
        $data = $request->validate([
            'date' => ['nullable', 'date_format:Y-m-d'],
            'time' => ['sometimes', 'nullable', 'string'],
            'guests' => ['sometimes', 'integer', 'min:1'],
            'occasion' => ['sometimes', 'nullable', 'string'],
            'requests' => ['sometimes', 'nullable', 'string'],
        ]);
        // Keep only the keys that were sent (ReservationEdit is a partial).
        $patch = [];
        foreach (['date', 'time', 'guests', 'occasion', 'requests'] as $k) {
            if ($request->has($k)) {
                $patch[$k] = $k === 'guests' ? (int) $data[$k] : ($data[$k] ?? '');
            }
        }
        if (empty($patch['date'])) {
            unset($patch['date']);
        }
        Actions::updateReservation($id, $patch);

        return response()->json(['ok' => true]);
    }
}
