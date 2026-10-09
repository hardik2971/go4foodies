<?php

namespace App\Http\Controllers\Api\Support;

use Illuminate\Http\Request;

final class Body
{
    /** `await req.json().catch(() => null)` — decoded JSON (assoc arrays) or null when unparseable. */
    public static function json(Request $req): mixed
    {
        $raw = $req->getContent();
        if ($raw === '' || $raw === false) {
            return null;
        }
        try {
            return json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        } catch (\JsonException) {
            return null;
        }
    }

    /** `(await req.json().catch(() => ({}))) ?? {}` — always an array. */
    public static function object(Request $req): array
    {
        $j = self::json($req);

        return is_array($j) ? $j : [];
    }
}
