<?php

use App\Http\Controllers\Admin\StaffController;
use Illuminate\Support\Facades\Route;

Route::middleware('perm:manage:staff')->group(function () {
    Route::get('/staff', [StaffController::class, 'index'])->name('staff');
    Route::post('/staff', [StaffController::class, 'store']);
    Route::put('/staff/{id}', [StaffController::class, 'update']);
    Route::patch('/staff/{id}/status', [StaffController::class, 'status']);
    Route::patch('/staff/{id}/active', [StaffController::class, 'active']);
    Route::delete('/staff/{id}', [StaffController::class, 'destroy']);
});
