<?php

use App\Http\Middleware\MobileAuth;
use App\Http\Middleware\RequirePermission;
use App\Support\ForbiddenException;
use App\Support\HttpError;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        // Same paths as the Next.js admin (/api/...) so the website + mobile app can switch backends.
        api: __DIR__.'/../routes/api.php',
        apiPrefix: 'api',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'perm' => RequirePermission::class,
            'mobile' => MobileAuth::class,
        ]);
        $middleware->redirectGuestsTo('/login');
        $middleware->redirectUsersTo('/dashboard');
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $wantsJson = fn (Request $r) => $r->is('api/*') || $r->expectsJson();

        // actions throw Forbidden → 403 JSON, or back to the dashboard for pages
        $exceptions->render(function (ForbiddenException $e, Request $r) use ($wantsJson) {
            return $wantsJson($r)
                ? response()->json(['error' => 'You do not have permission for this action'], 403)
                : redirect('/dashboard')->with('error', 'You do not have permission for that.');
        });

        $exceptions->render(function (HttpError $e, Request $r) use ($wantsJson) {
            return $wantsJson($r) ? response()->json(['error' => $e->getMessage()], $e->status) : null;
        });

        // Validation → {error, issues} like the zod responses of the Next.js API
        $exceptions->render(function (ValidationException $e, Request $r) use ($wantsJson) {
            if (! $wantsJson($r)) {
                return null;
            }
            $first = collect($e->errors())->flatten()->first() ?? 'Invalid input';

            return response()->json(['error' => $first, 'errors' => $e->errors()], 400);
        });

        // Missing row on update/delete → 404 {error}.
        $exceptions->render(function (\Illuminate\Database\Eloquent\ModelNotFoundException $e, Request $r) use ($wantsJson) {
            return $wantsJson($r) ? response()->json(['error' => 'Not found'], 404) : null;
        });

        // Never leak DB internals to API clients.
        $exceptions->render(function (\Illuminate\Database\QueryException $e, Request $r) use ($wantsJson) {
            report($e);

            return $wantsJson($r)
                ? response()->json(['error' => 'The restaurant database is unavailable. Please try again shortly.'], 503)
                : null;
        });

        // Plain action errors ("Session is closed", "Item not found") are safe to show —
        // same as errorResponse() in the Next admin's mobile-auth.ts.
        $exceptions->render(function (\RuntimeException $e, Request $r) use ($wantsJson) {
            if (! $wantsJson($r) || $e instanceof \Symfony\Component\HttpKernel\Exception\HttpExceptionInterface) {
                return null;
            }
            report($e);

            return response()->json(['error' => $e->getMessage() ?: 'Server error'], 500);
        });
    })->create();
