<?php

namespace App\Http\Controllers\Api\Mobile;

use App\Http\Controllers\Api\Support\Body;
use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\MobileErrors;
use App\Http\Controllers\Api\Support\Z;
use App\Http\Controllers\Controller;
use App\Services\MobileUsers;
use App\Support\CurrentUser;
use App\Support\HttpError;
use App\Support\MobileJwt;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** /api/mobile/auth/{login,register,me,password} — port of app/api/mobile/auth/**. */
class AuthController extends Controller
{
    private const INVALID = 'Invalid email or password';

    /** bcrypt compatible with bcryptjs ($2a$/$2b$/$2y$ all verify; new hashes use $2b$). */
    public static function hash(string $plain): string
    {
        return '$2b$'.substr(password_hash($plain, PASSWORD_BCRYPT, ['cost' => 10]), 4);
    }

    private static function check(string $plain, ?string $hash): bool
    {
        return $hash !== null && $hash !== '' && password_verify($plain, $hash);
    }

    /** POST /api/mobile/auth/login — one endpoint, three apps (customer | restaurant | owner). */
    public function login(Request $req)
    {
        try {
            $d = Z::parse(Z::object([
                'email' => Z::string(['email' => 'Enter a valid email']),
                'password' => Z::string(['min' => [1, 'Password is required']]),
                'app' => Z::enum(['customer', 'restaurant', 'owner']),
            ]), Body::json($req) ?? []);
            $fail = fn (string $msg = self::INVALID, int $status = 401) => Json::error($msg, $status);
            ['email' => $email, 'password' => $password, 'app' => $app] = $d;

            if ($app === 'customer') {
                $c = DB::table('Customer')->where('email', $email)->first();
                if (! $c || ! $c->password || ! self::check($password, $c->password)) {
                    return $fail();
                }
                if ($c->status !== 'ACTIVE') {
                    return $fail('This account is inactive. Please contact the restaurant.', 403);
                }
                $user = MobileUsers::customerSession($c);
            } else {
                $u = DB::table('User')->where('email', $email)->first();
                if ($u && self::check($password, $u->password)) {
                    if ($app === 'owner' && $u->role !== 'OWNER') {
                        return $fail('Owner access only. Use the Restaurant app.', 403);
                    }
                    $user = ['id' => $u->id, 'name' => $u->name, 'email' => $u->email, 'role' => $u->role, 'outletId' => $u->outletId, 'kind' => 'user'];
                } elseif ($app === 'restaurant') {
                    $e = DB::table('Employee')->where('email', $email)->first();
                    if (! $e || ! $e->password || ! self::check($password, $e->password)) {
                        return $fail();
                    }
                    if (! $e->active) {
                        return $fail('Your staff account is inactive.', 403);
                    }
                    $user = ['id' => $e->id, 'name' => $e->name, 'email' => $e->email ?? $email,
                        'role' => MobileUsers::employeeRole($e->role), 'outletId' => $e->outletId, 'kind' => 'employee'];
                } else {
                    return $fail();
                }
            }

            return Json::response(['token' => MobileJwt::sign($user), 'user' => MobileUsers::mobileProfile($user)]);
        } catch (\Throwable $e) {
            return MobileErrors::respond($e);
        }
    }

    /** POST /api/mobile/auth/register — Customer app sign-up (claims a guest Customer row). */
    public function register(Request $req)
    {
        try {
            $d = Z::parse(Z::object([
                'name' => Z::string(['trim' => true, 'min' => [2, 'Name is required']]),
                'email' => Z::string(['trim' => true, 'lower' => true, 'email' => 'Enter a valid email']),
                'phone' => Z::string(['trim' => true, 'min' => [5, 'Enter a valid phone number']]),
                'password' => Z::string(['min' => [6, 'Password must be at least 6 characters']]),
            ]), Body::json($req) ?? []);

            $existing = \App\Models\Customer::where('email', $d['email'])->first();
            if ($existing?->password) {
                return Json::error('An account with this email already exists. Please sign in.', 409);
            }
            $password = self::hash($d['password']);
            if ($existing) {
                $existing->fill(['name' => $d['name'], 'phone' => $d['phone'], 'password' => $password]);
                $existing->updatedAt = now();
                $existing->save();
                $c = $existing;
            } else {
                $c = \App\Models\Customer::create(['name' => $d['name'], 'email' => $d['email'], 'phone' => $d['phone'], 'password' => $password]);
            }
            $user = MobileUsers::customerSession($c);

            return Json::response(['token' => MobileJwt::sign($user), 'user' => MobileUsers::mobileProfile($user)], 201);
        } catch (\Throwable $e) {
            return MobileErrors::respond($e);
        }
    }

    /** GET /api/mobile/auth/me — current profile (+ permissions for staff apps). */
    public function me()
    {
        try {
            return Json::noStore(['user' => MobileUsers::mobileProfile(CurrentUser::get())]);
        } catch (\Throwable $e) {
            return MobileErrors::respond($e);
        }
    }

    /** PUT /api/mobile/auth/me — update own name / phone (/ address for customers). */
    public function updateMe(Request $req)
    {
        try {
            $user = CurrentUser::get();
            $optStr = Z::union([Z::optional(Z::string(['trim' => true])), Z::literal('')]);
            $d = Z::parse(Z::object([
                'name' => Z::string(['trim' => true, 'min' => [2, 'Name is required']]),
                'phone' => $optStr,
                'address' => $optStr,
            ]), Body::json($req) ?? []);
            $phone = ($d['phone'] ?? '') ?: null;
            if ($user['kind'] === 'customer') {
                DB::table('Customer')->where('id', $user['id'])->update(['name' => $d['name'], 'phone' => $phone,
                    'address' => ($d['address'] ?? '') ?: null, 'updatedAt' => now()->format('Y-m-d H:i:s.v')]);
            } elseif ($user['kind'] === 'employee') {
                DB::table('Employee')->where('id', $user['id'])->update(['name' => $d['name'], 'phone' => $phone]);
            } else {
                DB::table('User')->where('id', $user['id'])->update(['name' => $d['name'], 'updatedAt' => now()->format('Y-m-d H:i:s.v')]);
            }

            return Json::noStore(['user' => MobileUsers::mobileProfile(['name' => $d['name']] + $user)]);
        } catch (\Throwable $e) {
            return MobileErrors::respond($e);
        }
    }

    /** POST /api/mobile/auth/password — change own password (any of the 3 apps). */
    public function password(Request $req)
    {
        try {
            $user = CurrentUser::get();
            $d = Z::parse(Z::object([
                'currentPassword' => Z::string(['min' => [1, 'Current password is required']]),
                'newPassword' => Z::string(['min' => [6, 'New password must be at least 6 characters']]),
            ]), Body::json($req) ?? []);
            $table = match ($user['kind']) {
                'customer' => 'Customer',
                'employee' => 'Employee',
                default => 'User',
            };
            $current = DB::table($table)->where('id', $user['id'])->value('password');
            if (! $current || ! self::check($d['currentPassword'], $current)) {
                throw new HttpError(400, 'Current password is incorrect');
            }
            $update = ['password' => self::hash($d['newPassword'])];
            if ($table !== 'Employee') {
                $update['updatedAt'] = now()->format('Y-m-d H:i:s.v');
            }
            DB::table($table)->where('id', $user['id'])->update($update);

            return Json::noStore(['ok' => true]);
        } catch (\Throwable $e) {
            return MobileErrors::respond($e);
        }
    }
}
