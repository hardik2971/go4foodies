<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\Actions;
use App\Services\Queries;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** /gift-cards — port of app/(dashboard)/gift-cards/page.tsx + components/giftcards/GiftCardsManager.tsx */
class GiftCardController extends Controller
{
    /** schemas/giftcard.ts */
    public const KINDS = ['GIFT_CARD', 'COUPON'];

    public const STATUSES = ['PENDING_PAYMENT', 'PAID', 'ACTIVE', 'REDEEMED', 'EXPIRED', 'CANCELLED'];

    public const PAYMENT_STATUSES = ['PENDING', 'PAID', 'FAILED'];

    public function index()
    {
        try {
            $cards = Queries::getGiftCards();
        } catch (\Throwable $e) {
            report($e);
            $cards = [];
        }

        return view('gift-cards.index', ['cards' => $cards]);
    }

    /** giftCardEditSchema */
    public function update(Request $request, string $id): JsonResponse
    {
        $data = $request->validate([
            'customerName' => ['required', 'string', 'min:2'],
            'customerEmail' => ['nullable', 'email'],
            'kind' => ['required', Rule::in(self::KINDS)],
            'amount' => ['required', 'numeric', 'gt:0'],
            'status' => ['required', Rule::in(self::STATUSES)],
            'paymentStatus' => ['required', Rule::in(self::PAYMENT_STATUSES)],
            'expiryDate' => ['nullable', 'date_format:Y-m-d'],
        ], [
            'customerName.required' => 'Name is required',
            'customerName.min' => 'Name is required',
            'customerEmail.email' => 'Invalid email',
            'amount.gt' => 'Amount must be positive',
            'amount.required' => 'Amount must be positive',
            'amount.numeric' => 'Amount must be positive',
        ]);

        Actions::updateGiftCard($id, [
            'customerName' => $data['customerName'],
            'customerEmail' => $data['customerEmail'] ?? '',
            'kind' => $data['kind'],
            'amount' => (float) $data['amount'],
            'status' => $data['status'],
            'paymentStatus' => $data['paymentStatus'],
            'expiryDate' => $data['expiryDate'] ?? '',
        ]);

        return response()->json(['ok' => true]);
    }

    public function status(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::in(self::STATUSES)]]);
        Actions::setGiftCardStatus($id, $data['status']);

        return response()->json(['ok' => true]);
    }

    public function destroy(string $id): JsonResponse
    {
        Actions::deleteGiftCard($id);

        return response()->json(['ok' => true]);
    }
}
