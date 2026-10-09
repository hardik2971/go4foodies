<?php

use App\Http\Controllers\Admin\FloorController;
use Illuminate\Support\Facades\Route;

// Live floor plan — app/(dashboard)/floor/page.tsx (requirePermission('manage:tables')).
// Live updates: the page polls /floor/version every 5s (an SSE connection would block
// php artisan serve's single worker) and reloads /floor/data when it changes.
Route::middleware('perm:manage:tables')->group(function () {
    Route::get('/floor', [FloorController::class, 'index'])->name('floor.index');
    Route::get('/floor/data', [FloorController::class, 'data'])->name('floor.data');
    Route::get('/floor/version', [FloorController::class, 'version'])->name('floor.version');
    // Session/state mutations — Actions authorize operate:floor themselves.
    Route::post('/floor/tables/{tableId}/open', [FloorController::class, 'open'])->name('floor.open');
    Route::post('/floor/sessions/{sessionId}/close', [FloorController::class, 'close'])->name('floor.close');
    Route::patch('/floor/tables/{tableId}/state', [FloorController::class, 'state'])->name('floor.state');
});
