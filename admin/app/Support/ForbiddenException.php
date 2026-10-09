<?php

namespace App\Support;

use RuntimeException;

/** Raised by CurrentUser::authorize() — rendered as 403 (JSON) or a redirect (web). */
class ForbiddenException extends RuntimeException {}
