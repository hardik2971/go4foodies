<?php

namespace App\Support;

/** Granular permissions by role — mirrors admin/src/lib/rbac.ts exactly. */
final class Rbac
{
    public const ACTIONS = [
        'view:dashboard',
        'manage:menu',
        'manage:orders',
        'manage:reservations',
        'manage:tables',
        'operate:floor', // open/close table sessions, change live table state
        'manage:coupons',
        'manage:outlets',
        'manage:staff',
        'manage:customers',
        'manage:inventory',
        'view:reports',
        'manage:settings',
    ];

    // OWNER can do everything; MANAGER runs day-to-day ops; STAFF is read/operate-only.
    private const PERMISSIONS = [
        'OWNER' => '*',
        'MANAGER' => [
            'view:dashboard', 'manage:menu', 'manage:orders', 'manage:reservations', 'manage:tables',
            'operate:floor', 'manage:coupons', 'manage:outlets', 'manage:staff', 'manage:customers',
            'manage:inventory', 'view:reports',
        ],
        // STAFF runs the floor (open/close table sessions) but can't edit the table list.
        'STAFF' => ['view:dashboard', 'manage:orders', 'manage:reservations', 'operate:floor'],
    ];

    public static function can(?string $role, string $action): bool
    {
        if (! $role || ! isset(self::PERMISSIONS[$role])) {
            return false;
        }
        $p = self::PERMISSIONS[$role];

        return $p === '*' || in_array($action, $p, true);
    }

    /** @return string[] */
    public static function permissions(?string $role): array
    {
        return array_values(array_filter(self::ACTIONS, fn ($a) => self::can($role, $a)));
    }
}
