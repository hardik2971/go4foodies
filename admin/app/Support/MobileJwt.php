<?php

namespace App\Support;

/**
 * HS256 JWTs for the Flutter app — byte-compatible with admin/src/lib/mobile-auth.ts
 * (same AUTH_SECRET, payload and 30-day TTL), so a token from either backend works on both.
 */
final class MobileJwt
{
    private const TTL = 60 * 60 * 24 * 30;

    private static function secret(): string
    {
        $s = config('go4foodie.auth_secret');
        if (! $s) {
            throw new \RuntimeException('AUTH_SECRET is not set');
        }

        return $s;
    }

    private static function b64(string $s): string
    {
        return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
    }

    private static function unb64(string $s): string|false
    {
        return base64_decode(strtr($s, '-_', '+/'), true);
    }

    /** @param array{id:string,name:string,email:string,role:?string,outletId:?string,kind:string} $user */
    public static function sign(array $user): string
    {
        $header = self::b64(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
        $now = time();
        $payload = self::b64(json_encode([
            'sub' => $user['id'],
            'id' => $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'role' => $user['role'],
            'outletId' => $user['outletId'],
            'kind' => $user['kind'],
            'aud' => 'mobile',
            'iat' => $now,
            'exp' => $now + self::TTL,
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
        $sig = self::b64(hash_hmac('sha256', "$header.$payload", self::secret(), true));

        return "$header.$payload.$sig";
    }

    /** @return array{id:string,name:string,email:string,role:?string,outletId:?string,kind:string}|null */
    public static function verify(string $token): ?array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return null;
        }
        [$header, $payload, $sig] = $parts;
        $expected = hash_hmac('sha256', "$header.$payload", self::secret(), true);
        $given = self::unb64($sig);
        if ($given === false || ! hash_equals($expected, $given)) {
            return null;
        }
        $p = json_decode((string) self::unb64($payload), true);
        if (! is_array($p) || ($p['aud'] ?? null) !== 'mobile' || ! is_numeric($p['exp'] ?? null) || $p['exp'] < time()) {
            return null;
        }

        return [
            'id' => $p['id'],
            'name' => $p['name'] ?? '',
            'email' => $p['email'] ?? '',
            'role' => $p['role'] ?? null,
            'outletId' => $p['outletId'] ?? null,
            'kind' => $p['kind'] ?? 'customer',
        ];
    }

    public static function fromRequest(\Illuminate\Http\Request $req): ?array
    {
        $h = (string) $req->header('Authorization', '');

        return preg_match('/^Bearer\s+(.+)$/i', $h, $m) ? self::verify($m[1]) : null;
    }
}
