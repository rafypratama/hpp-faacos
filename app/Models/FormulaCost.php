<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['formula_id', 'type', 'description', 'cost_value'])]
class FormulaCost extends Model
{
    protected $casts = [
        'cost_value' => 'decimal:2',
    ];

    public function formula(): BelongsTo
    {
        return $this->belongsTo(Formula::class);
    }
}
