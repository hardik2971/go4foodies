<?php

use App\Http\Controllers\Admin\InventoryController;
use Illuminate\Support\Facades\Route;

Route::middleware('perm:manage:inventory')->group(function () {
    Route::get('/inventory', [InventoryController::class, 'index'])->name('inventory');
    Route::post('/inventory', [InventoryController::class, 'store']);
    Route::put('/inventory/{id}', [InventoryController::class, 'update']);
    Route::patch('/inventory/{id}/adjust', [InventoryController::class, 'adjust']);
    Route::delete('/inventory/{id}', [InventoryController::class, 'destroy']);
});
