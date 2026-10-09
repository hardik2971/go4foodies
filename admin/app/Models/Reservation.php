<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Reservation extends BaseModel
{
    protected $table = 'Reservation';

    protected $casts = ['date' => 'datetime', 'guests' => 'integer'];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customerId');
    }
}
