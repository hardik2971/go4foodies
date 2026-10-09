<?php

namespace App\Support;

use RuntimeException;

/** An error with an HTTP status and a client-safe message — rendered as {error}. */
class HttpError extends RuntimeException
{
    public function __construct(public int $status, string $message)
    {
        parent::__construct($message);
    }
}
