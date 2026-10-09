<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Queries;

/** /outlets — port of app/(dashboard)/outlets/page.tsx + components/outlets/OutletsManager.tsx (hidden from nav). */
class OutletController extends Controller
{
    public function index()
    {
        try {
            $outlets = Queries::getOutlets();
        } catch (\Throwable $e) {
            report($e);
            $outlets = [];
        }

        return view('outlets.index', ['outlets' => $outlets]);
    }
}
