<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use App\Support\CurrentUser;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** /settings — port of app/(dashboard)/settings/page.tsx + components/settings/SettingsView.tsx */
class SettingsController extends Controller
{
    private const FALLBACK_PROFILE = [
        'name' => 'Go4Foodie',
        'currency' => 'USD',
        'timezone' => 'America/New_York',
        'address' => '245 Harbor View Avenue, Boston, MA',
        'phone' => '+1 617 482 6060',
        'email' => 'hello@go4foodie.com',
    ];

    public function index()
    {
        try {
            $profile = Queries::getProfile();
        } catch (\Throwable $e) {
            report($e);
            $profile = self::FALLBACK_PROFILE;
        }
        try {
            $team = Queries::getUsers();
        } catch (\Throwable $e) {
            report($e);
            $team = [];
        }

        $me = CurrentUser::get();
        $account = [
            'name' => $me['name'] ?? 'User',
            'email' => $me['email'] ?? '',
            'role' => $me['role'] ?? '',
        ];

        return view('settings.index', compact('profile', 'team', 'account'));
    }

    /** profileSchema */
    public function profile(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2'],
            'currency' => ['required', 'string', 'min:1'],
            'timezone' => ['required', 'string', 'min:1'],
            'address' => ['nullable', 'string'],
            'phone' => ['nullable', 'string'],
            'email' => ['nullable', 'email'],
        ], [
            'name.required' => 'Restaurant name is required',
            'name.min' => 'Restaurant name is required',
            'email.email' => 'Enter a valid email',
        ]);

        Actions::updateProfile([
            'name' => $data['name'],
            'currency' => $data['currency'],
            'timezone' => $data['timezone'],
            'address' => $data['address'] ?? '',
            'phone' => $data['phone'] ?? '',
            'email' => $data['email'] ?? '',
        ]);

        return response()->json(['ok' => true]);
    }

    /** passwordSchema → changePassword() for the signed-in admin user. Returns {ok, error?}. */
    public function password(Request $request): JsonResponse
    {
        $data = $request->validate([
            'currentPassword' => ['required', 'string'],
            'newPassword' => ['required', 'string', 'min:6'],
        ], [
            'currentPassword.required' => 'Current password is required',
            'newPassword.required' => 'New password must be at least 6 characters',
            'newPassword.min' => 'New password must be at least 6 characters',
        ]);

        $res = Actions::changePassword($data);

        return response()->json($res);
    }
}
