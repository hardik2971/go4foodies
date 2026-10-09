<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Body;
use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\Schemas;
use App\Http\Controllers\Api\Support\Z;
use App\Http\Controllers\Controller;
use App\Services\OnlineOrder;
use Illuminate\Http\Request;

/** POST /api/orders — the public website's online ordering flow (TAKE_AWAY | DINE_IN). */
class OrderController extends Controller
{
    public function store(Request $req)
    {
        [$data, $issues] = Z::safeParse(Schemas::onlineOrder(), Body::json($req));
        if ($issues) {
            return Json::error('Invalid order', 400, ['issues' => $issues]);
        }

        return OnlineOrder::placeOnlineOrder($data);
    }
}
