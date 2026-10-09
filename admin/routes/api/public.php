<?php

// Public website API (no auth) + admin-session helpers — same paths/JSON as the Next.js admin.

use App\Http\Controllers\Api\DirectoryController;
use App\Http\Controllers\Api\FloorStreamController;
use App\Http\Controllers\Api\GiftCardController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ReservationController;
use App\Http\Controllers\Api\Support\RawCacheControl;
use App\Http\Controllers\Api\TableController;
use App\Http\Controllers\Api\UploadController;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Support\Facades\Route;

Route::middleware(RawCacheControl::class)->group(function () {
    Route::get('menu', [MenuController::class, 'index']);
    Route::post('orders', [OrderController::class, 'store']);

    Route::get('reservations', [ReservationController::class, 'index']);
    Route::post('reservations', [ReservationController::class, 'store']);
    Route::get('reservations/availability', [ReservationController::class, 'availability']);

    Route::get('tables/{code}', [TableController::class, 'show']);

    Route::get('payment', [PaymentController::class, 'index']);
    Route::post('payment', [PaymentController::class, 'store']);
    Route::post('payment/capture', [PaymentController::class, 'capture']);

    Route::post('gift-cards', [GiftCardController::class, 'store']);

    // Ported as-is from the Next.js admin (no auth there either).
    Route::get('customers', [DirectoryController::class, 'customers']);
    Route::get('staff', [DirectoryController::class, 'staff']);
    Route::post('staff', [DirectoryController::class, 'createStaff']);
    Route::get('outlets', [DirectoryController::class, 'outlets']);
    Route::post('outlets', [DirectoryController::class, 'createOutlet']);

    Route::get('uploads/{name}', [UploadController::class, 'show']);

    // Routes that accept the admin web session (cookie) — session started without CSRF.
    Route::middleware([EncryptCookies::class, AddQueuedCookiesToResponse::class, StartSession::class])->group(function () {
        Route::post('upload', [UploadController::class, 'store']);
        Route::get('floor-stream', [FloorStreamController::class, 'stream']);
    });
});
