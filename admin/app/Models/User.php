<?php

namespace App\Models;

use Illuminate\Auth\Authenticatable as AuthenticatableTrait;
use Illuminate\Contracts\Auth\Authenticatable;

/** Admin login (Prisma `User`). Roles: OWNER | MANAGER | STAFF. */
class User extends BaseModel implements Authenticatable
{
    use AuthenticatableTrait;

    protected $table = 'User';

    protected $hidden = ['password'];

    // Prisma has no remember_token column.
    public function getRememberTokenName()
    {
        return '';
    }
}
