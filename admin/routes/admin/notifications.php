<?php

use App\Http\Controllers\Admin\NotificationController;
use Illuminate\Support\Facades\Route;

// Any signed-in user (the file is loaded inside the `auth` group).
Route::get('/notifications', [NotificationController::class, 'index'])->name('notifications');
