<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** /inventory — port of app/(dashboard)/inventory/page.tsx + components/inventory/InventoryManager.tsx */
class InventoryController extends Controller
{
    /** schemas/inventory.ts INVENTORY_CATEGORIES */
    public const CATEGORIES = ['Produce', 'Meat & Fish', 'Dairy', 'Beverage', 'Dry Goods', 'Bakery'];

    public function index()
    {
        try {
            $items = Queries::getInventory();
        } catch (\Throwable $e) {
            report($e);
            $items = [];
        }

        return view('inventory.index', ['items' => $items, 'categories' => self::CATEGORIES]);
    }

    public function store(Request $request): JsonResponse
    {
        Actions::createInventoryItem($this->input($request));

        return response()->json(['ok' => true, 'items' => Queries::getInventory()]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        Actions::updateInventoryItem($id, $this->input($request));

        return response()->json(['ok' => true]);
    }

    public function adjust(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['delta' => ['required', 'numeric']]);
        Actions::adjustInventory($id, $data['delta'] + 0);

        return response()->json(['ok' => true]);
    }

    public function destroy(string $id): JsonResponse
    {
        Actions::deleteInventoryItem($id);

        return response()->json(['ok' => true]);
    }

    /** inventoryItemSchema (zod) — same rules and messages. */
    private function input(Request $request): array
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2'],
            'category' => ['required', Rule::in(self::CATEGORIES)],
            'unit' => ['required', 'string', 'min:1'],
            'quantity' => ['required', 'numeric', 'min:0'],
            'reorderLevel' => ['required', 'numeric', 'min:0'],
            'costPerUnit' => ['required', 'numeric', 'min:0'],
            'supplier' => ['nullable', 'string'],
        ], [
            'name.required' => 'Name is required',
            'name.min' => 'Name is required',
            'unit.required' => 'Unit is required',
            'unit.min' => 'Unit is required',
        ]);

        return [
            'name' => $data['name'],
            'category' => $data['category'],
            'unit' => $data['unit'],
            'quantity' => $data['quantity'] + 0,
            'reorderLevel' => $data['reorderLevel'] + 0,
            'costPerUnit' => $data['costPerUnit'] + 0,
            'supplier' => $data['supplier'] ?? '',
        ];
    }
}
