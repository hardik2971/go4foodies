<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MenuItem extends BaseModel
{
    protected $table = 'MenuItem';

    protected $casts = ['price' => 'float', 'rating' => 'float', 'available' => 'boolean'];

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'categoryId');
    }

    public function orderItems(): HasMany
    {
        return $this->hasMany(OrderItem::class, 'menuItemId');
    }
}
