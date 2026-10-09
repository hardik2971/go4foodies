<?php

use App\Http\Controllers\Admin\TableAnalyticsController;
use Illuminate\Support\Facades\Route;

// Table analytics + per-table history — requirePermission('view:reports')
Route::middleware('perm:view:reports')->group(function () {
    Route::get('/table-analytics', [TableAnalyticsController::class, 'index'])->name('table-analytics.index');
    Route::get('/table-history/{tableId}', [TableAnalyticsController::class, 'history'])->name('table-history.show');
});
