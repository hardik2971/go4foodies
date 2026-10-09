<?php

namespace App\Http\Controllers\Api\Support;

use App\Support\Iso;
use Illuminate\Http\JsonResponse;

/**
 * JSON helpers that reproduce what the Next.js API emits:
 *  - NextResponse.json(): JSON.stringify output (unescaped slashes/unicode, whole floats as ints)
 *  - raw Prisma rows: Decimal → string ("12.5"), Boolean → bool, DateTime → ISO string
 */
final class Json
{
    public const FLAGS = JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE;

    public static function response(mixed $data, int $status = 200, array $headers = []): JsonResponse
    {
        if (isset($headers['Cache-Control'])) {
            $headers[RawCacheControl::HEADER] = $headers['Cache-Control']; // applied verbatim by RawCacheControl
        }

        return new JsonResponse(self::normalize($data), $status, $headers, self::FLAGS);
    }

    /** `new Response(text, {status})` — text/plain like the Web Response API. */
    public static function text(string $body, int $status, array $headers = []): \Illuminate\Http\Response
    {
        return response($body, $status, ['Content-Type' => 'text/plain;charset=UTF-8'] + $headers);
    }

    /** Same, with Cache-Control: no-store (most website-facing endpoints). */
    public static function noStore(mixed $data, int $status = 200): JsonResponse
    {
        return self::response($data, $status, ['Cache-Control' => 'no-store']);
    }

    public static function error(string $message, int $status, array $extra = []): JsonResponse
    {
        return self::response(['error' => $message] + $extra, $status);
    }

    /** JS numbers have no int/float split: print 12.0 as 12 like JSON.stringify. */
    public static function normalize(mixed $v): mixed
    {
        if (is_float($v)) {
            if (is_nan($v) || is_infinite($v)) {
                return null; // JSON.stringify(NaN) === 'null'
            }

            return floor($v) == $v && abs($v) < 9.0E15 ? (int) $v : $v;
        }
        if (is_array($v)) {
            foreach ($v as $k => $x) {
                $v[$k] = self::normalize($x);
            }

            return $v;
        }
        if ($v instanceof \DateTimeInterface) {
            return Iso::of($v);
        }
        if ($v instanceof \JsonSerializable) {
            return self::normalize($v->jsonSerialize());
        }

        return $v;
    }

    /** Prisma Decimal#toJSON(): "12.50" → "12.5", "12.00" → "12". */
    public static function decimal(mixed $v): ?string
    {
        if ($v === null) {
            return null;
        }
        $s = is_string($v) ? $v : Json::numStr((float) $v);
        if (str_contains($s, '.')) {
            $s = rtrim(rtrim($s, '0'), '.');
        }
        if ($s === '-0' || $s === '') {
            $s = '0';
        }

        return $s;
    }

    private static function numStr(float $f): string
    {
        return rtrim(rtrim(number_format($f, 10, '.', ''), '0'), '.');
    }

    /**
     * Serialize a raw DB row like Prisma does.
     *
     * @param  array<string,string>  $types  column => dec|bool|int|float|date
     * @param  string[]  $omit
     */
    public static function row(object|array $row, array $types = [], array $omit = []): array
    {
        $out = [];
        foreach ((array) $row as $k => $v) {
            if (in_array($k, $omit, true)) {
                continue;
            }
            $t = $types[$k] ?? null;
            if ($v !== null) {
                $v = match ($t) {
                    'dec' => self::decimal($v),
                    'bool' => (bool) $v,
                    'int' => (int) $v,
                    'float' => (float) $v,
                    'date' => Iso::of($v),
                    default => $v,
                };
            }
            $out[$k] = $v;
        }

        return $out;
    }
}
