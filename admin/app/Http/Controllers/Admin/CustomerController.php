<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** /customers — port of app/(dashboard)/customers/page.tsx + components/customers/CustomersManager.tsx */
class CustomerController extends Controller
{
    public function index()
    {
        try {
            $customers = Queries::getCustomers();
        } catch (\Throwable $e) {
            report($e);
            $customers = [];
        }

        return view('customers.index', ['customers' => $customers]);
    }

    public function store(Request $request): JsonResponse
    {
        Actions::createCustomer($this->input($request));

        return response()->json(['ok' => true, 'customers' => Queries::getCustomers()]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        Actions::updateCustomer($id, $this->input($request));

        return response()->json(['ok' => true]);
    }

    public function destroy(string $id): JsonResponse
    {
        Actions::deleteCustomer($id);

        return response()->json(['ok' => true]);
    }

    /** customerSchema (zod) — same rules and messages. */
    private function input(Request $request): array
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2'],
            'email' => ['required', 'email'],
            'phone' => ['nullable', 'string'],
            'address' => ['nullable', 'string'],
            'status' => ['nullable', Rule::in(['ACTIVE', 'INACTIVE'])],
        ], [
            'name.required' => 'Name is required',
            'name.min' => 'Name is required',
            'email.required' => 'Enter a valid email',
            'email.email' => 'Enter a valid email',
        ]);

        return [
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? '',
            'address' => $data['address'] ?? '',
            'status' => $data['status'] ?? 'ACTIVE',
        ];
    }
}
