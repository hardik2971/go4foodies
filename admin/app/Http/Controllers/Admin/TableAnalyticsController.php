<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Queries;
use Illuminate\Http\Request;

/** /table-analytics + /table-history/{tableId} — ports of the Next pages + components/analytics/* */
class TableAnalyticsController extends Controller
{
    public function index(Request $request)
    {
        $days = in_array((int) $request->query('days'), [1, 7, 30], true) ? (int) $request->query('days') : 1;

        return view('table-analytics.index', ['data' => Queries::getTableAnalytics($days)]);
    }

    public function history(Request $request, string $tableId)
    {
        $days = in_array((int) $request->query('days'), [1, 7, 30], true) ? (int) $request->query('days') : 30;

        return view('table-analytics.history', ['data' => Queries::getTableHistory($tableId, $days), 'days' => $days]);
    }
}
