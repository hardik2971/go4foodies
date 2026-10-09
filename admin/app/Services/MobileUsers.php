<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Employee;
use App\Support\Rbac;

/** Account lookups + public profile shapes for the Flutter app's three logins (mobile-users.ts). */
final class MobileUsers
{
    /** Employee directory roles → RBAC role used by the Restaurant app. */
    public static function employeeRole(?string $role): string
    {
        return preg_match('/manager|super admin/i', (string) $role) ? 'MANAGER' : 'STAFF';
    }

    /**
     * Profile returned by login / me — what the app renders and gates on.
     *
     * @param  array{id:string,name:string,email:string,role:?string,outletId:?string,kind:string}  $user
     */
    public static function mobileProfile(array $user): array
    {
        $base = [
            'id' => $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'kind' => $user['kind'],
            'role' => $user['role'],
            'permissions' => Rbac::permissions($user['role']),
        ];
        if ($user['kind'] === 'customer') {
            $c = Customer::find($user['id']);

            return $base + ['phone' => $c?->phone ?? '', 'address' => $c?->address ?? ''];
        }
        if ($user['kind'] === 'employee') {
            $e = Employee::find($user['id']);

            return $base + ['phone' => $e?->phone ?? '', 'title' => $e?->role ?? 'Staff', 'dutyStatus' => $e?->status ?? 'OFF'];
        }
        $title = $user['role'] === 'OWNER' ? 'Owner' : ($user['role'] === 'MANAGER' ? 'Manager' : 'Staff');

        return $base + ['phone' => '', 'title' => $title];
    }

    /** @return array{id:string,name:string,email:string,role:null,outletId:null,kind:string} */
    public static function customerSession(object $c): array
    {
        return ['id' => $c->id, 'name' => $c->name, 'email' => $c->email, 'role' => null, 'outletId' => null, 'kind' => 'customer'];
    }
}
