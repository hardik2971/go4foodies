<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;

class Category extends BaseModel
{
    protected $table = 'Category';

    public $timestamps = false;

    protected $casts = ['active' => 'boolean'];

    public function items(): HasMany
    {
        return $this->hasMany(MenuItem::class, 'categoryId');
    }
}
