<?php

use App\Http\Controllers\Admin\ReservationController;
use Illuminate\Support\Facades\Route;

// Reservations — app/(dashboard)/reservations/page.tsx (requirePermission('manage:reservations'))
Route::middleware('perm:manage:reservations')->group(function () {
    Route::get('/reservations', [ReservationController::class, 'index'])->name('reservations.index');
    Route::patch('/reservations/{id}/status', [ReservationController::class, 'status'])->name('reservations.status');
    Route::patch('/reservations/{id}', [ReservationController::class, 'update'])->name('reservations.update');
});
