<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TableSession extends BaseModel
{
    protected $table = 'TableSession';

    protected $casts = ['openedAt' => 'datetime', 'closedAt' => 'datetime', 'customerCount' => 'integer', 'subtotal' => 'float', 'discount' => 'float', 'tax' => 'float', 'serviceCharge' => 'float', 'tip' => 'float', 'total' => 'float'];

    public function table(): BelongsTo
    {
        return $this->belongsTo(RestaurantTable::class, 'tableId');
    }

    public function waiter(): BelongsTo
    {
        return $this->belongsTo(Employee::class, 'waiterId');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customerId');
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'sessionId');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class, 'sessionId');
    }
}
