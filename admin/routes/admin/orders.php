<?php

use App\Http\Controllers\Admin\OrderController;
use Illuminate\Support\Facades\Route;

// Orders — app/(dashboard)/orders/page.tsx (requirePermission('manage:orders'))
Route::middleware('perm:manage:orders')->group(function () {
    Route::get('/orders', [OrderController::class, 'index'])->name('orders.index');
    Route::patch('/orders/{id}/status', [OrderController::class, 'status'])->name('orders.status');
});
