<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** /staff — port of app/(dashboard)/staff/page.tsx + components/staff/StaffManager.tsx */
class StaffController extends Controller
{
    /** schemas/staff.ts STAFF_ROLES */
    public const ROLES = ['Super Admin', 'Manager', 'Cashier', 'Kitchen Staff', 'Waiter'];

    public const DUTY = ['ON_DUTY', 'ON_BREAK', 'ABSENT', 'OFF'];

    public function index()
    {
        try {
            $employees = Queries::getEmployees();
        } catch (\Throwable $e) {
            report($e);
            $employees = [];
        }

        return view('staff.index', ['employees' => $employees, 'roles' => self::ROLES]);
    }

    public function store(Request $request): JsonResponse
    {
        Actions::createStaff($this->input($request));

        return response()->json(['ok' => true, 'employees' => Queries::getEmployees()]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        Actions::updateStaff($id, $this->input($request));

        return response()->json(['ok' => true]);
    }

    public function status(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::in(self::DUTY)]]);
        Actions::setEmployeeStatus($id, $data['status']);

        return response()->json(['ok' => true]);
    }

    public function active(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['active' => ['required', 'boolean']]);
        Actions::setStaffActive($id, (bool) $data['active']);

        return response()->json(['ok' => true]);
    }

    public function destroy(string $id): JsonResponse
    {
        Actions::deleteStaff($id);

        return response()->json(['ok' => true]);
    }

    /** staffSchema (zod) — same rules and messages. */
    private function input(Request $request): array
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2'],
            'email' => ['required', 'email'],
            'phone' => ['nullable', 'string'],
            'password' => ['nullable', 'string', 'min:6'],
            'role' => ['required', Rule::in(self::ROLES)],
            'active' => ['boolean'],
        ], [
            'name.required' => 'Name is required',
            'name.min' => 'Name is required',
            'email.required' => 'Enter a valid email',
            'email.email' => 'Enter a valid email',
            'password.min' => 'Min 6 characters',
        ]);

        return [
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? '',
            'password' => $data['password'] ?? '',
            'role' => $data['role'],
            'active' => (bool) ($data['active'] ?? true),
        ];
    }
}
