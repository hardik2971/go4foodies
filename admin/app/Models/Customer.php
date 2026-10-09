<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;

class Customer extends BaseModel
{
    protected $table = 'Customer';

    protected $hidden = ['password'];

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'customerId');
    }

    public function reservations(): HasMany
    {
        return $this->hasMany(Reservation::class, 'customerId');
    }

    public function giftCards(): HasMany
    {
        return $this->hasMany(GiftCard::class, 'customerId');
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(TableSession::class, 'customerId');
    }
}
