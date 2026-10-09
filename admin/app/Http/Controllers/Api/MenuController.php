<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

/** GET /api/menu — public menu feed for the website (online ordering + QR menu). */
class MenuController extends Controller
{
    public function index()
    {
        try {
            // Only available items in active categories — disabled categories, hidden
            // and unavailable products never reach the storefront.
            $rows = DB::table('MenuItem as m')
                ->join('Category as c', 'c.id', '=', 'm.categoryId')
                ->where('m.available', true)
                ->where('c.active', true)
                ->orderBy('c.name')
                ->orderBy('m.name')
                ->get(['m.id', 'm.name', 'm.description', 'm.price', 'm.rating', 'm.tag', 'm.imageUrl', 'c.name as category']);

            $items = $rows->map(fn ($r) => [
                'id' => $r->id,
                'name' => $r->name,
                'description' => $r->description,
                'price' => (float) $r->price,
                'rating' => (float) $r->rating,
                'tag' => $r->tag ?? '',
                'category' => $r->category,
                'imageUrl' => $r->imageUrl,
            ])->all();

            $categories = array_values(array_unique(array_column($items, 'category')));

            return Json::noStore(['items' => $items, 'categories' => $categories]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Menu unavailable', 503);
        }
    }
}
