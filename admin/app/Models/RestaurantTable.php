<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;

/** Prisma `Table`: status = QR ordering on/off, state = live floor state. */
class RestaurantTable extends BaseModel
{
    protected $table = 'Table';

    protected $casts = ['capacity' => 'integer'];

    protected static function booted(): void
    {
        parent::booted();
        // QR token — Prisma @default(cuid())
        static::creating(function (self $t) {
            $t->code = $t->code ?: \App\Support\Cuid::make();
        });
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'tableId');
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(TableSession::class, 'tableId');
    }
}
