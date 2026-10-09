<?php

use App\Http\Controllers\Admin\GiftCardController;
use Illuminate\Support\Facades\Route;

Route::middleware('perm:manage:coupons')->group(function () {
    Route::get('/gift-cards', [GiftCardController::class, 'index'])->name('gift-cards');
    Route::put('/gift-cards/{id}', [GiftCardController::class, 'update']);
    Route::patch('/gift-cards/{id}/status', [GiftCardController::class, 'status']);
    Route::delete('/gift-cards/{id}', [GiftCardController::class, 'destroy']);
});
