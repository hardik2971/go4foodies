<?php

namespace App\Http\Controllers\Api\Support;

use Illuminate\Contracts\Support\Responsable;

/**
 * Thrown by Z::parse() — mirrors mobile-auth.ts errorResponse() for a ZodError:
 * 400 {error: first issue message, issues}.
 */
class ZodError extends \RuntimeException implements Responsable
{
    public function __construct(public array $issues)
    {
        parent::__construct($issues[0]['message'] ?? 'Invalid input');
    }

    public function toResponse($request)
    {
        return response()->json(['error' => $this->issues[0]['message'] ?? 'Invalid input', 'issues' => $this->issues], 400);
    }

    /** Laravel calls render() on exceptions that define it. */
    public function render($request)
    {
        return $this->toResponse($request);
    }
}
