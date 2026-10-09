<?php

namespace App\Http\Controllers\Api\Support;

use App\Support\ForbiddenException;
use App\Support\HttpError;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/** Port of mobile-auth.ts errorResponse(): map thrown errors to JSON responses. */
final class MobileErrors
{
    public static function respond(\Throwable $err): JsonResponse
    {
        if ($err instanceof HttpError) {
            return Json::error($err->getMessage(), $err->status);
        }
        if ($err instanceof ZodError) {
            return Json::error($err->issues[0]['message'] ?? 'Invalid input', 400, ['issues' => $err->issues]);
        }
        if ($err instanceof ValidationException) {
            // App\Services\Validation (port of the zod schemas used by actions.ts) → zod-like issues.
            $issues = [];
            foreach ($err->errors() as $field => $messages) {
                foreach ((array) $messages as $m) {
                    $issues[] = ['code' => 'custom', 'path' => $field === '' ? [] : explode('.', (string) $field), 'message' => $m];
                }
            }

            return Json::error($issues[0]['message'] ?? 'Invalid input', 400, ['issues' => $issues]);
        }
        if ($err instanceof ForbiddenException || $err->getMessage() === 'Forbidden') {
            return Json::error('You do not have permission for this action', 403);
        }
        report($err);
        // Never leak DB internals; plain action errors ("Session is closed") are safe to show.
        // ModelNotFoundException = Prisma P2025 ("Record to update not found") → a Prisma error in the TS.
        if ($err instanceof \Illuminate\Database\QueryException || $err instanceof \PDOException
            || $err instanceof \Illuminate\Database\Eloquent\ModelNotFoundException) {
            return Json::error('The restaurant database is unavailable. Please try again shortly.', 503);
        }

        return Json::error($err->getMessage() !== '' ? $err->getMessage() : 'Server error', 500);
    }
}
