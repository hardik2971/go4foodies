<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Queries;

/** /reports — port of app/(dashboard)/reports/page.tsx + components/reports/ReportsView.tsx */
class ReportController extends Controller
{
    /** Minimal fallback if MySQL is unreachable, so the page still renders. */
    private const FALLBACK = [
        'summary' => ['revenue' => 0, 'orders' => 0, 'itemsSold' => 0, 'avgOrder' => 0],
        'revenueByOutlet' => [],
        'topItems' => [],
        'categoryMix' => [],
        'orderTypes' => [
            ['type' => 'Dine-in', 'count' => 0],
            ['type' => 'Delivery', 'count' => 0],
            ['type' => 'Pick-up', 'count' => 0],
        ],
        'paymentMix' => [
            ['method' => 'Cash', 'count' => 0],
            ['method' => 'Card', 'count' => 0],
            ['method' => 'Online', 'count' => 0],
        ],
    ];

    public function index()
    {
        try {
            $data = Queries::getReportsData();
        } catch (\Throwable $e) {
            report($e);
            $data = self::FALLBACK;
        }

        return view('reports.index', ['data' => $data]);
    }
}
