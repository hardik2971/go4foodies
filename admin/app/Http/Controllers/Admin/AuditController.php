<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Queries;

/** /audit — port of app/(dashboard)/audit/page.tsx */
class AuditController extends Controller
{
    public function index()
    {
        return view('audit.index', ['logs' => Queries::getAuditLogs(200)]);
    }
}
