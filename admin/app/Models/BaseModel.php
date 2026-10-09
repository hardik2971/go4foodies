<?php

namespace App\Models;

use App\Support\Cuid;
use App\Support\Iso;
use DateTimeInterface;
use Illuminate\Database\Eloquent\Model;

/**
 * Base for every table shared with the Next.js admin (Prisma schema).
 *  - string cuid primary keys generated app-side (Prisma @default(cuid()))
 *  - camelCase createdAt / updatedAt columns, datetime(3) stored in UTC
 *  - no mass-assignment guard (input is validated in controllers / services)
 */
abstract class BaseModel extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    const CREATED_AT = 'createdAt';

    const UPDATED_AT = 'updatedAt';

    protected $dateFormat = 'Y-m-d H:i:s.v';

    protected static function booted(): void
    {
        static::creating(function (Model $m) {
            if (! $m->getKey()) {
                $m->setAttribute($m->getKeyName(), Cuid::make());
            }
        });
    }

    protected function serializeDate(DateTimeInterface $date): string
    {
        return Iso::of($date);
    }
}
