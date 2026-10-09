<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;

class Employee extends BaseModel
{
    protected $table = 'Employee';

    const UPDATED_AT = null;

    protected $hidden = ['password'];

    protected $casts = ['active' => 'boolean'];

    public function sessions(): HasMany
    {
        return $this->hasMany(TableSession::class, 'waiterId');
    }
}
