<?php

// Flutter app API (bearer JWT) — /api/mobile/*, same paths/JSON as the Next.js admin.

use App\Http\Controllers\Api\Mobile\AuthController;
use App\Http\Controllers\Api\Mobile\CustomerController;
use App\Http\Controllers\Api\Mobile\StaffController;
use App\Http\Controllers\Api\Support\RawCacheControl;
use Illuminate\Support\Facades\Route;

Route::prefix('mobile')->middleware(RawCacheControl::class)->group(function () {
    Route::post('auth/login', [AuthController::class, 'login']);
    Route::post('auth/register', [AuthController::class, 'register']);

    Route::middleware('mobile:customer,user,employee')->group(function () {
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::put('auth/me', [AuthController::class, 'updateMe']);
        Route::post('auth/password', [AuthController::class, 'password']);
    });

    $verbs = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

    // Customer app — every path is dispatched by CustomerController's route table.
    Route::match($verbs, 'customer/{path}', [CustomerController::class, 'handle'])
        ->where('path', '.+')->middleware('mobile:customer');

    // Restaurant + Owner apps.
    Route::match($verbs, 'staff/{path}', [StaffController::class, 'handle'])
        ->where('path', '.+')->middleware('mobile:user,employee');
});
