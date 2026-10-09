<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Order extends BaseModel
{
    protected $table = 'Order';

    protected $casts = ['total' => 'float', 'scheduleDate' => 'datetime'];

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class, 'orderId');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customerId');
    }

    public function table(): BelongsTo
    {
        return $this->belongsTo(RestaurantTable::class, 'tableId');
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(TableSession::class, 'sessionId');
    }
}
