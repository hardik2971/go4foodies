<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payment extends BaseModel
{
    protected $table = 'Payment';

    const UPDATED_AT = null;

    protected $casts = ['amount' => 'float'];

    public function session(): BelongsTo
    {
        return $this->belongsTo(TableSession::class, 'sessionId');
    }
}
