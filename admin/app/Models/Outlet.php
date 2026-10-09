<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;

class Outlet extends BaseModel
{
    protected $table = 'Outlet';

    const UPDATED_AT = null;

    protected $casts = ['isActive' => 'boolean'];

    public function metrics(): HasMany
    {
        return $this->hasMany(OutletMetric::class, 'outletId');
    }
}
