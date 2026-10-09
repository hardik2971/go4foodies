<?php

namespace App\Http\Controllers\Api\Support;

use App\Support\CurrentUser;
use App\Support\Rbac;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Port of mobile-router.ts: a tiny route table for /api/mobile/{customer,staff}/{path}.
 * Each route: method + pattern ("sessions/:id/items") + optional RBAC action → handler.
 * Token kind is enforced by the `mobile:<kinds>` middleware before dispatch.
 *
 * Handler signature: fn(MobileCtx $ctx): mixed — arrays become JSON (no-store),
 * a Response is returned as-is, null becomes {ok: true}.
 */
final class MobileRouter
{
    /** @var array<int, array{0:string,1:string,2:?string,3:callable}> */
    private array $routes = [];

    public function add(string $method, string $pattern, ?string $action, callable $handler): self
    {
        $this->routes[] = [$method, $pattern, $action, $handler];

        return $this;
    }

    private static function match(string $pattern, array $segments): ?array
    {
        $parts = explode('/', $pattern);
        if (count($parts) !== count($segments)) {
            return null;
        }
        $params = [];
        foreach ($parts as $i => $p) {
            if (str_starts_with($p, ':')) {
                $params[substr($p, 1)] = rawurldecode($segments[$i]);
            } elseif ($p !== $segments[$i]) {
                return null;
            }
        }

        return $params;
    }

    public function dispatch(Request $req, string $path): Response
    {
        $user = CurrentUser::get();
        $segments = explode('/', $path);
        try {
            foreach ($this->routes as [$method, $pattern, $action, $handler]) {
                if ($method !== $req->getMethod()) {
                    continue;
                }
                $params = self::match($pattern, $segments);
                if ($params === null) {
                    continue;
                }
                if ($action && ! Rbac::can($user['role'] ?? null, $action)) {
                    return Json::error('You do not have permission for this action', 403);
                }
                $result = $handler(new MobileCtx($user, $params, $req));
                if ($result instanceof Response) {
                    return $result;
                }

                return Json::noStore($result ?? ['ok' => true]);
            }

            return Json::error('Not found', 404);
        } catch (\Throwable $e) {
            return MobileErrors::respond($e);
        }
    }
}
