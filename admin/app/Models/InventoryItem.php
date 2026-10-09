<?php

namespace App\Models;

class InventoryItem extends BaseModel
{
    protected $table = 'InventoryItem';

    const CREATED_AT = null;

    protected $casts = ['quantity' => 'float', 'reorderLevel' => 'float', 'costPerUnit' => 'float'];
}
