<?php

use App\Http\Controllers\AuthController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/dashboard');

Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthController::class, 'show'])->name('login');
    Route::post('/login', [AuthController::class, 'login']);
});

Route::post('/logout', [AuthController::class, 'logout'])->middleware('auth')->name('logout');

// Admin panel modules — one routes file per area (see routes/admin/*.php).
Route::middleware('auth')->group(function () {
    foreach (glob(__DIR__.'/admin/*.php') as $file) {
        require $file;
    }
});
