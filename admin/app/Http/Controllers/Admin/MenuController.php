<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** /menu — port of app/(dashboard)/menu/page.tsx + components/menu/* */
class MenuController extends Controller
{
    /** schemas/menu.ts MENU_CATEGORIES */
    public const CATEGORIES = ['Breakfast', 'Starters', 'Main Meals', 'Fish', 'Pasta & Salads', 'Desserts', 'Drinks'];

    public function index()
    {
        try {
            $items = Queries::getMenuItems();
        } catch (\Throwable $e) {
            report($e);
            $items = [];
        }
        try {
            $categories = Queries::getMenuCategories();
        } catch (\Throwable $e) {
            report($e);
            $categories = [];
        }

        return view('menu.index', ['items' => $items, 'categories' => $categories, 'menuCategories' => self::CATEGORIES]);
    }

    public function store(Request $request): JsonResponse
    {
        Actions::createMenuItem($this->input($request));

        return response()->json(['ok' => true, 'items' => Queries::getMenuItems(), 'categories' => Queries::getMenuCategories()]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        Actions::updateMenuItem($id, $this->input($request));

        return response()->json(['ok' => true]);
    }

    public function destroy(string $id): JsonResponse
    {
        Actions::deleteMenuItem($id);

        return response()->json(['ok' => true]);
    }

    public function availability(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['available' => ['required', 'boolean']]);
        Actions::setMenuAvailability($id, (bool) $data['available']);

        return response()->json(['ok' => true]);
    }

    public function categoryActive(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['active' => ['required', 'boolean']]);
        Actions::setCategoryActive($id, (bool) $data['active']);

        return response()->json(['ok' => true]);
    }

    /** menuItemSchema (zod) — same rules and messages. */
    private function input(Request $request): array
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2'],
            'description' => ['required', 'string', 'min:4'],
            'price' => ['required', 'numeric', 'min:0'],
            'rating' => ['nullable', 'numeric', 'min:0', 'max:5'],
            'tag' => ['nullable', 'string'],
            'category' => ['required', Rule::in(self::CATEGORIES)],
            'imageUrl' => ['required', 'url'],
            'available' => ['boolean'],
        ], [
            'name.required' => 'Name is required',
            'name.min' => 'Name is required',
            'description.required' => 'Add a short description',
            'description.min' => 'Add a short description',
            'price.min' => 'Price must be positive',
            'imageUrl.required' => 'Enter a valid image URL',
            'imageUrl.url' => 'Enter a valid image URL',
        ]);

        return [
            'name' => $data['name'],
            'description' => $data['description'],
            'price' => (float) $data['price'],
            'rating' => (float) ($data['rating'] ?? 0),
            'tag' => $data['tag'] ?? null,
            'category' => $data['category'],
            'imageUrl' => $data['imageUrl'],
            'available' => (bool) ($data['available'] ?? true),
        ];
    }
}
