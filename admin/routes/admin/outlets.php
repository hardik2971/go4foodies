<?php

use App\Http\Controllers\Admin\OutletController;
use Illuminate\Support\Facades\Route;

Route::get('/outlets', [OutletController::class, 'index'])
    ->middleware('perm:manage:outlets')->name('outlets');
