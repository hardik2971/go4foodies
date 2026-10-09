<?php

namespace App\Http\Middleware;

use App\Support\CurrentUser;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Page guard — mirrors guard.ts requirePermission(): signed in + permission,
 * else redirect to /dashboard (pages) or 403 (JSON).  Usage: ->middleware('perm:manage:orders')
 */
class RequirePermission
{
    public function handle(Request $request, Closure $next, string $action): Response
    {
        if (! CurrentUser::can($action)) {
            if ($request->expectsJson()) {
                return response()->json(['error' => 'You do not have permission for this action'], 403);
            }

            return redirect('/dashboard')->with('error', 'You do not have permission for that page.');
        }

        return $next($request);
    }
}
