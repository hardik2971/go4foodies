<?php

namespace App\Http\Controllers\Api\Support;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\ResponseHeaderBag;

/**
 * Makes /api Cache-Control headers byte-identical to the Next.js API.
 *
 * Symfony always computes a Cache-Control ("no-cache, private" when unset, "no-store, private"
 * for "no-store"), and MobileAuth stamps "no-store" on every mobile response. The Next.js
 * routes only send one where the handler sets it explicitly (NextResponse.json(..., {headers})
 * or withMobileUser's plain-object results). Handlers declare that intent with the
 * X-Raw-Cache-Control header (Json::noStore() etc.); this middleware applies it verbatim and
 * drops every other Cache-Control.
 */
class RawCacheControl
{
    public const HEADER = 'X-Raw-Cache-Control';

    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);
        $intent = $response->headers->get(self::HEADER);

        $bag = new class([]) extends ResponseHeaderBag
        {
            protected function computeCacheControlValue(): string
            {
                return $this->getCacheControlHeader(); // no implied "private"
            }

            /** Store the header exactly as written (Symfony would re-sort the directives). */
            public function setRaw(string $name, string $value): void
            {
                $this->headers[strtolower($name)] = [$value];
                $this->headerNames[strtolower($name)] = $name;
            }
        };
        foreach ($response->headers->allPreserveCaseWithoutCookies() as $name => $values) {
            $lower = strtolower($name);
            if ($lower === 'cache-control' || $lower === strtolower(self::HEADER)) {
                continue;
            }
            $bag->set($name, $values);
        }
        foreach ($response->headers->getCookies() as $cookie) {
            $bag->setCookie($cookie);
        }
        $bag->remove('Cache-Control');
        if ($intent !== null && $intent !== '') {
            $bag->setRaw('Cache-Control', $intent);
        }
        $response->headers = $bag;

        return $response;
    }
}
