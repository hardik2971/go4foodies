<?php

use App\Http\Controllers\Admin\TableController;
use Illuminate\Support\Facades\Route;

// Table management / QR codes — app/(dashboard)/tables/page.tsx (requirePermission('manage:tables'))
Route::middleware('perm:manage:tables')->group(function () {
    Route::get('/tables', [TableController::class, 'index'])->name('tables.index');
    Route::post('/tables', [TableController::class, 'store'])->name('tables.store');
    Route::put('/tables/{id}', [TableController::class, 'update'])->name('tables.update');
    Route::patch('/tables/{id}/status', [TableController::class, 'status'])->name('tables.status');
    Route::delete('/tables/{id}', [TableController::class, 'destroy'])->name('tables.destroy');
});
