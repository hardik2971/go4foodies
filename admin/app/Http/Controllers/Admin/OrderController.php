<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** /orders — port of app/(dashboard)/orders/page.tsx + components/orders/* */
class OrderController extends Controller
{
    public const STATUSES = ['PENDING', 'PREPARING', 'READY', 'COMPLETED', 'CANCELED'];

    public function index()
    {
        try {
            $orders = Queries::getOrders();
        } catch (\Throwable $e) {
            report($e);
            $orders = [];
        }

        return view('orders.index', ['orders' => $orders]);
    }

    /** OrderDetail "Mark …" buttons → setOrderStatus(id, status) */
    public function status(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::in(self::STATUSES)]]);
        Actions::setOrderStatus($id, $data['status']);

        return response()->json(['ok' => true]);
    }
}
