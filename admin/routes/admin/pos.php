<?php

use App\Http\Controllers\Admin\PosController;
use Illuminate\Support\Facades\Route;

// Table POS — app/(dashboard)/pos/[tableId]/page.tsx (requirePermission('manage:orders')).
// Mutations mirror the server actions PosScreen calls (each Action authorizes itself).
Route::middleware('perm:manage:orders')->group(function () {
    Route::get('/pos/{tableId}', [PosController::class, 'show'])->name('pos.show');
    Route::get('/pos/{tableId}/data', [PosController::class, 'data'])->name('pos.data');
    Route::post('/pos/{tableId}/open', [PosController::class, 'open'])->name('pos.open');
    Route::post('/pos/sessions/{sessionId}/orders', [PosController::class, 'addOrder'])->name('pos.orders');
    Route::post('/pos/sessions/{sessionId}/decrement', [PosController::class, 'decrement'])->name('pos.decrement');
    Route::patch('/pos/sessions/{sessionId}/billing', [PosController::class, 'billing'])->name('pos.billing');
    Route::post('/pos/sessions/{sessionId}/merge', [PosController::class, 'merge'])->name('pos.merge');
    Route::post('/pos/sessions/{sessionId}/payments', [PosController::class, 'payment'])->name('pos.payments');
    Route::post('/pos/sessions/{sessionId}/close', [PosController::class, 'close'])->name('pos.close');
});
