<?php

namespace App\Models;

class OutletMetric extends BaseModel
{
    protected $table = 'OutletMetric';

    public $timestamps = false;

    protected $casts = ['periodStart' => 'datetime', 'revenue' => 'float', 'operationalCost' => 'float'];
}
