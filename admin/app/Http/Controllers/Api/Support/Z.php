<?php

namespace App\Http\Controllers\Api\Support;

/**
 * A tiny zod v3 look-alike for the public/mobile API schemas, so 400 bodies keep the
 * exact `{error, issues}` shape (codes, paths, default messages) of the Next.js admin.
 *
 * A schema is a closure: fn(mixed $value, array $path, array &$issues): mixed (parsed value).
 * Absent keys are represented by Z::$U (zod "undefined").
 */
final class Z
{
    /** Sentinel for "undefined" (absent key). */
    public static object $U;

    public static function init(): void
    {
        self::$U ??= new \stdClass;
    }

    public static function isU(mixed $v): bool
    {
        return $v === self::$U;
    }

    /** JS typeof-ish names zod reports in `received`. */
    public static function typeName(mixed $v): string
    {
        return match (true) {
            self::isU($v) => 'undefined',
            $v === null => 'null',
            is_bool($v) => 'boolean',
            is_int($v), is_float($v) => (is_float($v) && is_nan($v)) ? 'nan' : 'number',
            is_string($v) => 'string',
            is_array($v) && array_is_list($v) && ($v !== [] || false) => 'array',
            is_array($v), is_object($v) => 'object',
            default => 'unknown',
        };
    }

    private static function invalidType(string $expected, mixed $v, array $path): array
    {
        $received = self::typeName($v);

        return [
            'code' => 'invalid_type',
            'expected' => $expected,
            'received' => $received,
            'path' => $path,
            'message' => $received === 'undefined' ? 'Required' : "Expected $expected, received $received",
        ];
    }

    // ---------------------------------------------------------------- primitives

    /**
     * z.string() with checks: ['min'=>[n,msg?], 'max'=>[n,msg?], 'email'=>msg?, 'trim'=>true, 'lower'=>true]
     */
    public static function string(array $o = []): \Closure
    {
        return function ($v, array $path, array &$issues) use ($o) {
            if (! is_string($v)) {
                $issues[] = self::invalidType('string', $v, $path);

                return self::$U;
            }
            if (! empty($o['trim'])) {
                $v = trim($v);
            }
            if (! empty($o['lower'])) {
                $v = mb_strtolower($v);
            }
            $len = mb_strlen($v);
            if (isset($o['min']) && $len < $o['min'][0]) {
                $n = $o['min'][0];
                $issues[] = ['code' => 'too_small', 'minimum' => $n, 'type' => 'string', 'inclusive' => true, 'exact' => false,
                    'message' => $o['min'][1] ?? "String must contain at least $n character(s)", 'path' => $path];
            }
            if (isset($o['max']) && $len > $o['max'][0]) {
                $n = $o['max'][0];
                $issues[] = ['code' => 'too_big', 'maximum' => $n, 'type' => 'string', 'inclusive' => true, 'exact' => false,
                    'message' => $o['max'][1] ?? "String must contain at most $n character(s)", 'path' => $path];
            }
            if (array_key_exists('email', $o) && ! self::isEmail($v)) {
                $issues[] = ['validation' => 'email', 'code' => 'invalid_string', 'message' => $o['email'] ?? 'Invalid email', 'path' => $path];
            }

            return $v;
        };
    }

    /** zod v3 emailRegex. */
    public static function isEmail(string $v): bool
    {
        return (bool) preg_match("/^(?!\\.)(?!.*\\.\\.)([A-Z0-9_'+\\-\\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\\-]*\\.)+[A-Z]{2,}$/i", $v);
    }

    /**
     * z.number() / z.coerce.number() with checks:
     * ['coerce'=>bool, 'int'=>bool, 'min'=>[n,msg?], 'max'=>[n,msg?], 'positive'=>msg|true]
     */
    public static function number(array $o = []): \Closure
    {
        return function ($v, array $path, array &$issues) use ($o) {
            if (! empty($o['coerce'])) {
                $v = self::jsNumber($v);
            }
            if (! (is_int($v) || is_float($v)) || is_nan((float) $v)) {
                $issues[] = self::invalidType('number', $v, $path);

                return self::$U;
            }
            if (! empty($o['int']) && floor((float) $v) != $v) {
                $issues[] = ['code' => 'invalid_type', 'expected' => 'integer', 'received' => 'float', 'message' => 'Expected integer, received float', 'path' => $path];
            }
            if (isset($o['positive']) && ! ($v > 0)) {
                $issues[] = ['code' => 'too_small', 'minimum' => 0, 'type' => 'number', 'inclusive' => false, 'exact' => false,
                    'message' => is_string($o['positive']) ? $o['positive'] : 'Number must be greater than 0', 'path' => $path];
            }
            if (isset($o['min']) && $v < $o['min'][0]) {
                $n = $o['min'][0];
                $issues[] = ['code' => 'too_small', 'minimum' => $n, 'type' => 'number', 'inclusive' => true, 'exact' => false,
                    'message' => $o['min'][1] ?? "Number must be greater than or equal to $n", 'path' => $path];
            }
            if (isset($o['max']) && $v > $o['max'][0]) {
                $n = $o['max'][0];
                $issues[] = ['code' => 'too_big', 'maximum' => $n, 'type' => 'number', 'inclusive' => true, 'exact' => false,
                    'message' => $o['max'][1] ?? "Number must be less than or equal to $n", 'path' => $path];
            }

            return is_float($v) && floor($v) == $v && abs($v) < PHP_INT_MAX ? (int) $v : $v;
        };
    }

    /** JS Number(x). */
    public static function jsNumber(mixed $v): int|float
    {
        if (self::isU($v)) {
            return NAN;
        }
        if ($v === null || $v === false) {
            return 0;
        }
        if ($v === true) {
            return 1;
        }
        if (is_int($v) || is_float($v)) {
            return $v;
        }
        if (is_string($v)) {
            $t = trim($v);
            if ($t === '') {
                return 0;
            }
            if (preg_match('/^[+-]?(\d+\.?\d*|\.\d+)(e[+-]?\d+)?$/i', $t)) {
                $f = (float) $t;

                return floor($f) == $f && abs($f) < PHP_INT_MAX ? (int) $f : $f;
            }
            if (preg_match('/^0x[0-9a-f]+$/i', $t)) {
                return hexdec($t);
            }
            if (in_array($t, ['Infinity', '+Infinity'], true)) {
                return INF;
            }
            if ($t === '-Infinity') {
                return -INF;
            }

            return NAN;
        }
        if (is_array($v)) {
            if ($v === []) {
                return 0;
            }
            if (array_is_list($v) && count($v) === 1) {
                return self::jsNumber(is_array($v[0]) ? NAN : (is_string($v[0]) || is_numeric($v[0]) ? $v[0] : NAN));
            }
        }

        return NAN;
    }

    public static function boolean(): \Closure
    {
        return function ($v, array $path, array &$issues) {
            if (! is_bool($v)) {
                $issues[] = self::invalidType('boolean', $v, $path);

                return self::$U;
            }

            return $v;
        };
    }

    public static function literal(string $expected): \Closure
    {
        return function ($v, array $path, array &$issues) use ($expected) {
            if ($v !== $expected) {
                $issues[] = ['received' => self::isU($v) ? null : $v, 'code' => 'invalid_literal', 'expected' => $expected, 'path' => $path,
                    'message' => 'Invalid literal value, expected '.json_encode($expected, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)];

                return self::$U;
            }

            return $v;
        };
    }

    /** @param string[] $options */
    public static function enum(array $options): \Closure
    {
        return function ($v, array $path, array &$issues) use ($options) {
            if (! is_string($v)) {
                // zod's enum emits expected/received before code
                $i = self::invalidType(implode(' | ', array_map(fn ($o) => "'$o'", $options)), $v, $path);
                $issues[] = ['expected' => $i['expected'], 'received' => $i['received'], 'code' => $i['code'], 'path' => $i['path'], 'message' => $i['message']];

                return self::$U;
            }
            if (! in_array($v, $options, true)) {
                $issues[] = ['received' => $v, 'code' => 'invalid_enum_value', 'options' => $options, 'path' => $path,
                    'message' => 'Invalid enum value. Expected '.implode(' | ', array_map(fn ($o) => "'$o'", $options)).", received '$v'"];

                return self::$U;
            }

            return $v;
        };
    }

    public static function unknown(): \Closure
    {
        return fn ($v) => $v;
    }

    // ---------------------------------------------------------------- modifiers

    public static function optional(\Closure $s): \Closure
    {
        return fn ($v, array $path, array &$issues) => self::isU($v) ? self::$U : $s($v, $path, $issues);
    }

    public static function default(\Closure $s, mixed $default): \Closure
    {
        return fn ($v, array $path, array &$issues) => $s(self::isU($v) ? $default : $v, $path, $issues);
    }

    /** a.or(b) — zod v3 union semantics (first success wins; otherwise invalid_union). */
    public static function union(array $options): \Closure
    {
        return function ($v, array $path, array &$issues) use ($options) {
            $dirty = null;
            $all = [];
            foreach ($options as $opt) {
                $own = [];
                $out = $opt($v, $path, $own);
                if (! $own) {
                    return $out;
                }
                // zod returns the first "dirty" (non-fatal) result's issues directly
                if ($dirty === null && self::allNonFatal($own)) {
                    $dirty = $own;
                }
                $all[] = $own;
            }
            if ($dirty !== null) {
                array_push($issues, ...$dirty);

                return self::$U;
            }
            $issues[] = ['code' => 'invalid_union',
                'unionErrors' => array_map(fn ($is) => ['issues' => $is, 'name' => 'ZodError'], $all),
                'path' => $path, 'message' => 'Invalid input'];

            return self::$U;
        };
    }

    /** too_small / too_big / invalid_string are non-fatal in zod (result is "dirty", not "aborted"). */
    private static function allNonFatal(array $issues): bool
    {
        foreach ($issues as $i) {
            if (! in_array($i['code'], ['too_small', 'too_big', 'invalid_string'], true)) {
                return false;
            }
        }

        return true;
    }

    /** z.object(shape) — strips unknown keys, collects every issue. */
    public static function object(array $shape): \Closure
    {
        return function ($v, array $path, array &$issues) use ($shape) {
            if (! is_array($v) || (array_is_list($v) && $v !== [])) {
                $issues[] = self::invalidType('object', $v, $path);

                return self::$U;
            }
            $out = [];
            foreach ($shape as $key => $schema) {
                $raw = array_key_exists($key, $v) ? $v[$key] : self::$U;
                $parsed = $schema($raw, [...$path, $key], $issues);
                if (! self::isU($parsed)) {
                    $out[$key] = $parsed;
                }
            }

            return $out;
        };
    }

    public static function array(\Closure $item, ?array $min = null): \Closure
    {
        return function ($v, array $path, array &$issues) use ($item, $min) {
            if (! is_array($v) || ! array_is_list($v)) {
                $issues[] = self::invalidType('array', $v, $path);

                return self::$U;
            }
            if ($min && count($v) < $min[0]) {
                $n = $min[0];
                $issues[] = ['code' => 'too_small', 'minimum' => $n, 'type' => 'array', 'inclusive' => true, 'exact' => false,
                    'message' => $min[1] ?? "Array must contain at least $n element(s)", 'path' => $path];
            }
            $out = [];
            foreach ($v as $i => $el) {
                $out[] = $item($el, [...$path, $i], $issues);
            }

            return $out;
        };
    }

    /** z.discriminatedUnion(key, [value => objectSchema]) */
    public static function discriminated(string $key, array $options): \Closure
    {
        return function ($v, array $path, array &$issues) use ($key, $options) {
            if (! is_array($v) || (array_is_list($v) && $v !== [])) {
                $issues[] = self::invalidType('object', $v, $path);

                return self::$U;
            }
            $d = $v[$key] ?? null;
            if (! is_string($d) || ! isset($options[$d])) {
                $issues[] = ['code' => 'invalid_union_discriminator', 'options' => array_keys($options), 'path' => [...$path, $key],
                    'message' => 'Invalid discriminator value. Expected '.implode(' | ', array_map(fn ($o) => "'$o'", array_keys($options)))];

                return self::$U;
            }

            return $options[$d]($v, $path, $issues);
        };
    }

    // ---------------------------------------------------------------- running

    /**
     * safeParse — returns [data|null, issues[]].
     *
     * @return array{0: mixed, 1: array}
     */
    public static function safeParse(\Closure $schema, mixed $value): array
    {
        self::init();
        $issues = [];
        $out = $schema($value ?? null, [], $issues);

        return [$issues ? null : $out, $issues];
    }

    /** parse — throws ZodError (rendered as 400 {error, issues}). */
    public static function parse(\Closure $schema, mixed $value): mixed
    {
        [$data, $issues] = self::safeParse($schema, $value);
        if ($issues) {
            throw new ZodError($issues);
        }

        return $data;
    }

    /** Field accessor for an "absent" aware array. */
    public static function get(array $a, string $k): mixed
    {
        self::init();

        return array_key_exists($k, $a) ? $a[$k] : self::$U;
    }
}

Z::init();
