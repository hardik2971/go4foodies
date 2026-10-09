<?php

namespace App\Support;

use Illuminate\Support\Facades\Auth;

/**
 * The signed-in principal, however they authenticated (mirrors session-user.ts):
 *  - admin web  → Laravel session (App\Models\User)
 *  - mobile app → bearer JWT (User, Employee or Customer), set by MobileAuth middleware
 * Customers carry no staff role, so Rbac::can() always denies them.
 *
 * @phpstan-type Principal array{id:string,name:string,email:string,role:?string,outletId:?string,kind:string}
 */
final class CurrentUser
{
    /** @var array{id:string,name:string,email:string,role:?string,outletId:?string,kind:string}|null */
    private static ?array $mobile = null;

    public static function setMobile(?array $user): void
    {
        self::$mobile = $user;
    }

    /** @return array{id:string,name:string,email:string,role:?string,outletId:?string,kind:string}|null */
    public static function get(): ?array
    {
        if (self::$mobile) {
            return self::$mobile;
        }
        $u = Auth::user();
        if (! $u) {
            return null;
        }

        return [
            'id' => $u->id,
            'name' => $u->name,
            'email' => $u->email,
            'role' => $u->role,
            'outletId' => $u->outletId,
            'kind' => 'user',
        ];
    }

    public static function can(string $action): bool
    {
        return Rbac::can(self::get()['role'] ?? null, $action);
    }

    /** Throws Forbidden (→ 403) like actions.ts authorize(). */
    public static function authorize(string $action): void
    {
        if (! self::can($action)) {
            throw new ForbiddenException('Forbidden');
        }
    }
}
