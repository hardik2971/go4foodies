<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Queries;

/** /transactions — port of app/(dashboard)/transactions/page.tsx + components/transactions/TransactionsView.tsx */
class TransactionController extends Controller
{
    public function index()
    {
        try {
            $transactions = Queries::getTransactions();
        } catch (\Throwable $e) {
            report($e);
            $transactions = [];
        }

        return view('transactions.index', ['transactions' => $transactions]);
    }
}
