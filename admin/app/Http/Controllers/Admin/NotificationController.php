<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Queries;

/** /notifications — port of app/(dashboard)/notifications/page.tsx (any signed-in user). */
class NotificationController extends Controller
{
    public function index()
    {
        try {
            $notifications = Queries::getNotifications();
        } catch (\Throwable $e) {
            report($e);
            $notifications = [];
        }

        return view('notifications.index', ['notifications' => $notifications]);
    }
}
