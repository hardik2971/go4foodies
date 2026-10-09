<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

/** GET /api/tables/{code} — public. Resolves a scanned table QR code (ACTIVE tables only). */
class TableController extends Controller
{
    public function show(string $code)
    {
        try {
            $t = DB::table('Table')->where('code', $code)->where('status', 'ACTIVE')
                ->first(['id', 'number', 'name', 'code']);
            if (! $t) {
                return Json::error('Table not found or inactive', 404);
            }

            return Json::noStore(['table' => (array) $t]);
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Lookup failed', 503);
        }
    }
}
