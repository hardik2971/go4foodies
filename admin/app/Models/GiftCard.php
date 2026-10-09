<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GiftCard extends BaseModel
{
    protected $table = 'GiftCard';

    protected $casts = ['amount' => 'float', 'expiryDate' => 'datetime'];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customerId');
    }
}
