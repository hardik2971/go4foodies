<?php

use App\Http\Controllers\Admin\TransactionController;
use Illuminate\Support\Facades\Route;

Route::get('/transactions', [TransactionController::class, 'index'])
    ->middleware('perm:view:reports')->name('transactions');
