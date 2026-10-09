<?php

namespace App\Services;

use Illuminate\Validation\ValidationException;

/**
 * The admin's zod schemas (admin/src/schemas/*.ts) ported 1:1 — same rules,
 * same coercion (z.coerce.number() = JS Number()), same defaults and the same
 * messages (custom ones, and zod v3's defaults otherwise). parse() returns the
 * cleaned data (unknown keys stripped, missing optional keys omitted) or throws
 * a ValidationException keyed by field, in schema order.
 */
final class Validation
{
    public const MENU_CATEGORIES = ['Breakfast', 'Starters', 'Main Meals', 'Fish', 'Pasta & Salads', 'Desserts', 'Drinks'];

    public const INVENTORY_CATEGORIES = ['Produce', 'Meat & Fish', 'Dairy', 'Beverage', 'Dry Goods', 'Bakery'];

    public const STAFF_ROLES = ['Super Admin', 'Manager', 'Cashier', 'Kitchen Staff', 'Waiter'];

    public const CUSTOMER_STATUSES = ['ACTIVE', 'INACTIVE'];

    public const TABLE_STATUSES = ['ACTIVE', 'INACTIVE'];

    public const COUPON_KINDS = ['GIFT_CARD', 'COUPON'];

    public const COUPON_STATUSES = ['PENDING_PAYMENT', 'PAID', 'ACTIVE', 'REDEEMED', 'EXPIRED', 'CANCELLED'];

    public const COUPON_PAYMENT_STATUSES = ['PENDING', 'PAID', 'FAILED'];

    /** zod v3 email regex. */
    private const EMAIL_RE = "/^(?!\\.)(?!.*\\.\\.)([A-Z0-9_'+\\-\\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\\-]*\\.)+[A-Z]{2,}$/i";

    /** Sentinel for "undefined" (key absent). */
    private const UNDEF = "\0undefined\0";

    // ---- Schemas ----

    /** menuItemSchema (schemas/menu.ts). */
    public static function menuItem(array $in): array
    {
        return self::parse($in, [
            'name' => ['string', 'min' => [2, 'Name is required']],
            'description' => ['string', 'min' => [4, 'Add a short description']],
            'price' => ['number', 'min' => [0, 'Price must be positive']],
            'rating' => ['number', 'min' => [0], 'max' => [5], 'default' => 0],
            'tag' => ['string', 'optional' => true],
            'category' => ['enum', 'values' => self::MENU_CATEGORIES],
            'imageUrl' => ['string', 'url' => 'Enter a valid image URL'],
            'available' => ['boolean', 'default' => true],
        ]);
    }

    /** inventoryItemSchema (schemas/inventory.ts). */
    public static function inventoryItem(array $in): array
    {
        return self::parse($in, [
            'name' => ['string', 'min' => [2, 'Name is required']],
            'category' => ['enum', 'values' => self::INVENTORY_CATEGORIES],
            'unit' => ['string', 'min' => [1, 'Unit is required']],
            'quantity' => ['number', 'min' => [0]],
            'reorderLevel' => ['number', 'min' => [0]],
            'costPerUnit' => ['number', 'min' => [0]],
            'supplier' => ['string', 'optional' => true],
        ]);
    }

    /** staffSchema (schemas/staff.ts). */
    public static function staff(array $in): array
    {
        return self::parse($in, [
            'name' => ['string', 'min' => [2, 'Name is required']],
            'email' => ['string', 'email' => 'Enter a valid email'],
            'phone' => ['string', 'optional' => true, 'orEmpty' => true],
            // Optional — empty on edit keeps the existing password; if provided, min 6.
            'password' => ['string', 'min' => [6, 'Min 6 characters'], 'optional' => true, 'orEmpty' => true],
            'role' => ['enum', 'values' => self::STAFF_ROLES],
            'active' => ['boolean', 'default' => true],
        ]);
    }

    /** customerSchema (schemas/customer.ts). */
    public static function customer(array $in): array
    {
        return self::parse($in, [
            'name' => ['string', 'min' => [2, 'Name is required']],
            'email' => ['string', 'email' => 'Enter a valid email'],
            'phone' => ['string', 'optional' => true, 'orEmpty' => true],
            'address' => ['string', 'optional' => true, 'orEmpty' => true],
            'status' => ['enum', 'values' => self::CUSTOMER_STATUSES, 'default' => 'ACTIVE'],
        ]);
    }

    /** tableSchema (schemas/table.ts). */
    public static function table(array $in): array
    {
        return self::parse($in, [
            'number' => ['string', 'min' => [1, 'Table number is required']],
            'name' => ['string', 'optional' => true, 'orEmpty' => true],
            'status' => ['enum', 'values' => self::TABLE_STATUSES, 'default' => 'ACTIVE'],
        ]);
    }

    /** giftCardEditSchema (schemas/giftcard.ts). */
    public static function giftCardEdit(array $in): array
    {
        return self::parse($in, [
            'customerName' => ['string', 'min' => [2, 'Name is required']],
            'customerEmail' => ['string', 'email' => 'Invalid email', 'optional' => true, 'orEmpty' => true],
            'kind' => ['enum', 'values' => self::COUPON_KINDS],
            'amount' => ['number', 'positive' => 'Amount must be positive'],
            'status' => ['enum', 'values' => self::COUPON_STATUSES],
            'paymentStatus' => ['enum', 'values' => self::COUPON_PAYMENT_STATUSES],
            'expiryDate' => ['string', 'optional' => true, 'orEmpty' => true], // "YYYY-MM-DD"
        ]);
    }

    /** profileSchema (schemas/settings.ts). */
    public static function profile(array $in): array
    {
        return self::parse($in, [
            'name' => ['string', 'min' => [2, 'Restaurant name is required']],
            'currency' => ['string', 'min' => [1]],
            'timezone' => ['string', 'min' => [1]],
            'address' => ['string', 'optional' => true],
            'phone' => ['string', 'optional' => true],
            'email' => ['string', 'email' => 'Enter a valid email', 'optional' => true, 'orEmpty' => true],
        ]);
    }

    /** passwordSchema (schemas/settings.ts). */
    public static function password(array $in): array
    {
        return self::parse($in, [
            'currentPassword' => ['string', 'min' => [1, 'Current password is required']],
            'newPassword' => ['string', 'min' => [6, 'New password must be at least 6 characters']],
        ]);
    }

    // ---- Engine ----

    /**
     * @param  array<string,array>  $shape  field => [type, ...options]
     *
     * @throws ValidationException
     */
    public static function parse(array $input, array $shape): array
    {
        $out = [];
        $errors = [];
        foreach ($shape as $field => $spec) {
            $value = array_key_exists($field, $input) ? $input[$field] : self::UNDEF;
            [$result, $issues] = self::field($value, $spec);
            if ($issues) {
                $errors[$field] = $issues;
            } elseif ($result !== self::UNDEF) {
                $out[$field] = $result;
            }
        }
        if ($errors) {
            throw ValidationException::withMessages($errors);
        }

        return $out;
    }

    /** @return array{0:mixed,1:string[]} [value, issues] */
    private static function field(mixed $value, array $spec): array
    {
        $type = $spec[0];
        if ($value === self::UNDEF && array_key_exists('default', $spec)) {
            $value = $spec['default'];
        }

        if ($type === 'string' && ! empty($spec['orEmpty'])) {
            // z.string()...optional().or(z.literal(''))
            if ($value === self::UNDEF) {
                return [self::UNDEF, []];
            }
            if (! is_string($value)) {
                return [null, ['Invalid input']];
            }
            $issues = self::stringChecks($value, $spec);
            if ($issues && $value !== '') {
                return [null, $issues];
            }

            return [$value, []];
        }

        if ($value === self::UNDEF && ! empty($spec['optional'])) {
            return [self::UNDEF, []];
        }

        switch ($type) {
            case 'string':
                if ($value === self::UNDEF || ! is_string($value)) {
                    return [null, [self::typeMessage('string', $value)]];
                }
                $issues = self::stringChecks($value, $spec);

                return [$value, $issues];

            case 'number':
                $n = $value === self::UNDEF ? NAN : self::jsNumber($value);
                if (is_nan($n)) {
                    return [null, ['Expected number, received nan']];
                }
                $issues = [];
                if (isset($spec['min']) && $n < $spec['min'][0]) {
                    $issues[] = $spec['min'][1] ?? "Number must be greater than or equal to {$spec['min'][0]}";
                }
                if (isset($spec['max']) && $n > $spec['max'][0]) {
                    $issues[] = $spec['max'][1] ?? "Number must be less than or equal to {$spec['max'][0]}";
                }
                if (isset($spec['positive']) && ! ($n > 0)) {
                    $issues[] = $spec['positive'];
                }

                return [is_finite($n) && abs($n) < PHP_INT_MAX && $n == (int) $n ? (int) $n : $n, $issues];

            case 'boolean':
                if (! is_bool($value)) {
                    return [null, [self::typeMessage('boolean', $value)]];
                }

                return [$value, []];

            case 'enum':
                $values = $spec['values'];
                $expected = implode(' | ', array_map(fn ($v) => "'$v'", $values));
                if ($value === self::UNDEF) {
                    return [null, ['Required']];
                }
                if (! is_string($value)) {
                    return [null, ["Expected $expected, received ".self::typeName($value)]];
                }
                if (! in_array($value, $values, true)) {
                    return [null, ["Invalid enum value. Expected $expected, received '$value'"]];
                }

                return [$value, []];
        }

        throw new \LogicException("Unknown schema type $type");
    }

    /** @return string[] */
    private static function stringChecks(string $v, array $spec): array
    {
        $issues = [];
        $len = intdiv(strlen((string) mb_convert_encoding($v, 'UTF-16LE', 'UTF-8')), 2); // JS .length
        if (isset($spec['min']) && $len < $spec['min'][0]) {
            $issues[] = $spec['min'][1] ?? "String must contain at least {$spec['min'][0]} character(s)";
        }
        if (isset($spec['max']) && $len > $spec['max'][0]) {
            $issues[] = $spec['max'][1] ?? "String must contain at most {$spec['max'][0]} character(s)";
        }
        if (isset($spec['email']) && ! preg_match(self::EMAIL_RE, $v)) {
            $issues[] = $spec['email'];
        }
        if (isset($spec['url']) && ! self::isUrl($v)) {
            $issues[] = $spec['url'];
        }

        return $issues;
    }

    /** Approximates `new URL(v)` succeeding (WHATWG): a scheme, and a host for special schemes. */
    private static function isUrl(string $v): bool
    {
        $v = trim($v, "\x00..\x20");
        if (! preg_match('/^([a-zA-Z][a-zA-Z0-9+.\-]*):(.*)$/s', $v, $m)) {
            return false;
        }
        if (preg_match('/[\t\n\r]/', $v)) {
            $v = preg_replace('/[\t\n\r]/', '', $v);
        }
        $scheme = strtolower($m[1]);
        if (in_array($scheme, ['http', 'https', 'ws', 'wss', 'ftp'], true)) {
            $rest = ltrim($m[2], '/\\');
            $authority = preg_split('#[/\\\\?\#]#', $rest, 2)[0];
            $host = preg_replace('/^.*@/', '', $authority);
            $host = preg_replace('/:\d*$/', '', $host);

            return $host !== '' && ! preg_match('/[\s<>^|%]/', $host);
        }

        return true;
    }

    /** JS Number(v) — what z.coerce.number() does. */
    public static function jsNumber(mixed $v): float|int
    {
        if ($v === null || $v === false) {
            return 0;
        }
        if ($v === true) {
            return 1;
        }
        if (is_int($v) || is_float($v)) {
            return $v;
        }
        if (is_array($v)) {
            return $v === [] ? 0 : (count($v) === 1 && ! is_array(reset($v)) ? self::jsNumber(is_string(reset($v)) ? reset($v) : (string) json_encode(reset($v))) : NAN);
        }
        if (! is_string($v)) {
            return NAN;
        }
        $s = trim($v, " \t\n\r\x0B\f\u{A0}\u{FEFF}\u{2028}\u{2029}");
        if ($s === '') {
            return 0;
        }
        if (preg_match('/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/', $s)) {
            return (float) $s;
        }
        if (preg_match('/^([+-]?)Infinity$/', $s, $m)) {
            return $m[1] === '-' ? -INF : INF;
        }
        if (preg_match('/^0[xX][0-9a-fA-F]+$/', $s)) {
            return (float) hexdec($s);
        }
        if (preg_match('/^0[oO][0-7]+$/', $s)) {
            return (float) octdec(substr($s, 2));
        }
        if (preg_match('/^0[bB][01]+$/', $s)) {
            return (float) bindec(substr($s, 2));
        }

        return NAN;
    }

    private static function typeMessage(string $expected, mixed $value): string
    {
        return $value === self::UNDEF ? 'Required' : "Expected $expected, received ".self::typeName($value);
    }

    /** zod getParsedType() names. */
    private static function typeName(mixed $v): string
    {
        return match (true) {
            $v === self::UNDEF => 'undefined',
            $v === null => 'null',
            is_bool($v) => 'boolean',
            is_float($v) && is_nan($v) => 'nan',
            is_int($v), is_float($v) => 'number',
            is_string($v) => 'string',
            is_array($v) => array_is_list($v) ? 'array' : 'object',
            default => 'object',
        };
    }
}
