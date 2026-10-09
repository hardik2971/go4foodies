<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use App\Support\CurrentUser;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** /dashboard — port of app/(dashboard)/dashboard/page.tsx + components/dashboard/* */
class DashboardController extends Controller
{
    public function index()
    {
        $data = $this->safe(fn () => Queries::getDashboardData(), null) ?? self::mock();
        $menuItems = $this->safe(fn () => Queries::getMenuItems(), []);
        $categories = $this->safe(fn () => Queries::getMenuCategories(), []);
        $cfg = $this->safe(fn () => Queries::getDashboardConfig(), ['trendingItemId' => null, 'topCategories' => null]);

        return view('dashboard.index', [
            'data' => $data,
            'editable' => CurrentUser::can('manage:menu'),
            'menuOptions' => array_map(fn ($m) => ['id' => $m['id'], 'name' => $m['name']], $menuItems),
            'categoryOptions' => array_map(fn ($c) => $c['name'], $categories),
            'currentItemId' => $cfg['trendingItemId'] ?? null,
        ]);
    }

    /** TrendingItem modal → setTrendingItem(itemId | null) */
    public function trending(Request $request): JsonResponse
    {
        $data = $request->validate(['itemId' => ['nullable', 'string']]);
        Actions::setTrendingItem($data['itemId'] ?? null);

        return response()->json(['ok' => true]);
    }

    /** TopCategories modal → setTopCategories(rows | null) */
    public function topCategories(Request $request): JsonResponse
    {
        $data = $request->validate([
            'categories' => ['nullable', 'array'],
            'categories.*.name' => ['required', 'string'],
            'categories.*.percent' => ['required', 'numeric'],
        ]);
        $rows = $data['categories'] ?? null;
        Actions::setTopCategories($rows === null ? null : array_map(
            fn ($r) => ['name' => $r['name'], 'percent' => $r['percent'] + 0],
            array_values($rows),
        ));

        return response()->json(['ok' => true]);
    }

    private function safe(callable $fn, mixed $fallback): mixed
    {
        try {
            return $fn();
        } catch (\Throwable $e) {
            report($e);

            return $fallback;
        }
    }

    /** Fallback used only if MySQL is unreachable (lib/dashboard-data.ts mocks). */
    private static function mock(): array
    {
        $img = fn (string $id, int $w = 800) => "https://images.unsplash.com/photo-{$id}?auto=format&fit=crop&w={$w}&q=70";

        return [
            'kpis' => [
                ['key' => 'orders', 'label' => 'Total Orders', 'value' => '1,250', 'delta' => 10, 'accent' => true],
                ['key' => 'delivered', 'label' => 'Total Delivered', 'value' => '1,070', 'delta' => 7.5],
                ['key' => 'canceled', 'label' => 'Canceled Order', 'value' => '180', 'delta' => -3.5],
                ['key' => 'revenue', 'label' => 'Total Revenue', 'value' => '$15,750', 'delta' => 7.5],
            ],
            'trending' => ['name' => 'Wood-fired Sea Bass', 'subtitle' => 'Chef’s Signature', 'rating' => 4.9, 'orders' => 420, 'price' => 32, 'image' => $img('1467003909585-2f8a72700288', 700)],
            'outletSeries' => [
                ['outlet' => 'Outlet 01', 'sells' => 7200, 'cost' => 5400],
                ['outlet' => 'Outlet 02', 'sells' => 9100, 'cost' => 8200],
                ['outlet' => 'Outlet 03', 'sells' => 8300, 'cost' => 11600],
                ['outlet' => 'Outlet 04', 'sells' => 9800, 'cost' => 8700],
                ['outlet' => 'Outlet 05', 'sells' => 10500, 'cost' => 14000],
                ['outlet' => 'Outlet 06', 'sells' => 11200, 'cost' => 9300],
                ['outlet' => 'Outlet 07', 'sells' => 9600, 'cost' => 12400],
                ['outlet' => 'Outlet 08', 'sells' => 12100, 'cost' => 10200],
            ],
            'outletActive' => 'Outlet 05',
            'revenueTotal' => '$3,500',
            'topCategories' => [
                ['name' => 'Fish', 'percent' => 65, 'image' => $img('1565299624946-b28f40a0ae38', 400)],
                ['name' => 'Drinks', 'percent' => 45, 'image' => $img('1551024709-8f23befc6f87', 400)],
                ['name' => 'Desserts', 'percent' => 81, 'image' => $img('1571877227200-a0d98ea607e9', 400)],
            ],
            'employee' => ['total' => 120, 'segments' => [
                ['label' => 'On Duty', 'value' => 83, 'color' => 'var(--color-success)'],
                ['label' => 'On Break', 'value' => 10, 'color' => 'var(--color-warn)'],
                ['label' => 'Absent', 'value' => 7, 'color' => 'var(--color-danger)'],
            ]],
            'pos' => ['totalSales' => '$1,550', 'salesDelta' => 12, 'totalBills' => 147, 'avgValue' => '$12', 'peakHour' => '5.00 PM', 'payment' => ['cash' => 60, 'card' => 25, 'online' => 15]],
            'recentOrders' => [
                ['line' => '01', 'orderId' => 'ORD-1042', 'customer' => 'Olivia Bennett', 'type' => 'Dine-in', 'status' => 'PREPARING', 'price' => 72, 'image' => $img('1546964124-0cce460f38ef', 400)],
                ['line' => '02', 'orderId' => 'ORD-1041', 'customer' => 'Liam Carter', 'type' => 'Delivery', 'status' => 'PENDING', 'price' => 41, 'image' => $img('1608897013039-887f21d8c804', 400)],
                ['line' => '03', 'orderId' => 'ORD-1040', 'customer' => 'Noah Patel', 'type' => 'Pick-up', 'status' => 'READY', 'price' => 30, 'image' => $img('1534080564583-6be75777b70a', 400)],
            ],
            'salesTypes' => [
                ['label' => 'Dine-in', 'percent' => 40],
                ['label' => 'Delivery', 'percent' => 35],
                ['label' => 'Pick-up', 'percent' => 25],
            ],
        ];
    }
}
