<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['formula_id', 'ingredient_id', 'quantity_per_batch', 'unit', 'unit_price', 'subtotal'])]
class FormulaIngredient extends Model
{
    protected $casts = [
        'quantity_per_batch' => 'decimal:4',
        'unit_price' => 'decimal:2',
        'subtotal' => 'decimal:2',
    ];

    public function formula(): BelongsTo
    {
        return $this->belongsTo(Formula::class);
    }

    public function ingredient(): BelongsTo
    {
        return $this->belongsTo(Ingredient::class);
    }
}
