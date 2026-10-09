<?php

use App\Http\Controllers\Admin\AuditController;
use Illuminate\Support\Facades\Route;

Route::get('/audit', [AuditController::class, 'index'])
    ->middleware('perm:manage:settings')->name('audit');
