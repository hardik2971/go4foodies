<?php

namespace App\Http\Controllers\Api\Support;

use Illuminate\Http\Request;

/** Route context for MobileRouter handlers (mobile-router.ts Ctx). */
final class MobileCtx
{
    private ?array $cached = null;

    public function __construct(
        public array $user,
        public array $params,
        public Request $req,
    ) {}

    /** Parsed JSON body, `{}` when missing/invalid (cached). */
    public function body(): array
    {
        return $this->cached ??= Body::object($this->req);
    }

    /** URLSearchParams#get */
    public function query(string $key): ?string
    {
        $v = $this->req->query($key);

        return is_string($v) ? $v : null;
    }
}
