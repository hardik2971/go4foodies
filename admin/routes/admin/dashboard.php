<?php

use App\Http\Controllers\Admin\DashboardController;
use Illuminate\Support\Facades\Route;

// Overview — app/(dashboard)/dashboard/page.tsx. Like the Next page it only needs a
// session (every role has view:dashboard; guarding it would loop the perm redirect).
Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');

// Editable widget overrides (Actions authorize manage:menu themselves).
Route::post('/dashboard/trending', [DashboardController::class, 'trending']);
Route::post('/dashboard/top-categories', [DashboardController::class, 'topCategories']);
