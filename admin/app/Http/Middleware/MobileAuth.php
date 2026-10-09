<?php

namespace App\Http\Middleware;

use App\Support\CurrentUser;
use App\Support\MobileJwt;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Bearer-token auth for the Flutter app (mirrors withMobileUser in mobile-auth.ts).
 * Usage: ->middleware('mobile:customer') or ->middleware('mobile:user,employee').
 * The verified token becomes the CurrentUser, so Actions authorize against it.
 */
class MobileAuth
{
    public function handle(Request $request, Closure $next, string ...$kinds): Response
    {
        $user = MobileJwt::fromRequest($request);
        if (! $user || ! in_array($user['kind'], $kinds, true)) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }
        CurrentUser::setMobile($user);
        try {
            $response = $next($request);
        } finally {
            CurrentUser::setMobile(null);
        }
        $response->headers->set('Cache-Control', 'no-store');

        return $response;
    }
}
