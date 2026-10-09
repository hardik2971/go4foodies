<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** /tables — port of app/(dashboard)/tables/page.tsx + components/tables/* */
class TableController extends Controller
{
    public function index()
    {
        try {
            $tables = Queries::getTables();
        } catch (\Throwable $e) {
            report($e);
            $tables = [];
        }

        return view('tables.index', [
            'tables' => $tables,
            'websiteUrl' => rtrim((string) config('go4foodie.website_url'), '/'),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $created = Actions::createTable($this->input($request));

        return response()->json(['ok' => true, 'table' => $created]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        Actions::updateTable($id, $this->input($request));

        return response()->json(['ok' => true]);
    }

    public function status(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::in(['ACTIVE', 'INACTIVE'])]]);
        Actions::setTableStatus($id, $data['status']);

        return response()->json(['ok' => true]);
    }

    public function destroy(string $id): JsonResponse
    {
        Actions::deleteTable($id);

        return response()->json(['ok' => true]);
    }

    /** tableSchema (zod) */
    private function input(Request $request): array
    {
        $data = $request->validate([
            'number' => ['required', 'string', 'min:1'],
            'name' => ['nullable', 'string'],
            'status' => ['nullable', Rule::in(['ACTIVE', 'INACTIVE'])],
        ], ['number.required' => 'Table number is required', 'number.min' => 'Table number is required']);

        return ['number' => $data['number'], 'name' => $data['name'] ?? '', 'status' => $data['status'] ?? 'ACTIVE'];
    }
}
