<?php

use App\Http\Controllers\Admin\MenuController;
use Illuminate\Support\Facades\Route;

// Menu — app/(dashboard)/menu/page.tsx (requirePermission('manage:menu'))
Route::middleware('perm:manage:menu')->group(function () {
    Route::get('/menu', [MenuController::class, 'index'])->name('menu.index');
    Route::post('/menu/items', [MenuController::class, 'store'])->name('menu.store');
    Route::put('/menu/items/{id}', [MenuController::class, 'update'])->name('menu.update');
    Route::delete('/menu/items/{id}', [MenuController::class, 'destroy'])->name('menu.destroy');
    Route::patch('/menu/items/{id}/availability', [MenuController::class, 'availability'])->name('menu.availability');
    Route::patch('/menu/categories/{id}/active', [MenuController::class, 'categoryActive'])->name('menu.category');
});
