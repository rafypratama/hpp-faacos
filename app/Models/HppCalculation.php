<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable([
    'formula_id', 
    'total_ingredient_cost', 
    'total_labor_cost', 
    'total_overhead_cost', 
    'total_other_cost', 
    'total_hpp', 
    'hpp_per_unit', 
    'profit_margin_percent', 
    'selling_price'
])]
class HppCalculation extends Model
{
    protected $casts = [
        'total_ingredient_cost' => 'decimal:2',
        'total_labor_cost' => 'decimal:2',
        'total_overhead_cost' => 'decimal:2',
        'total_other_cost' => 'decimal:2',
        'total_hpp' => 'decimal:2',
        'hpp_per_unit' => 'decimal:2',
        'profit_margin_percent' => 'decimal:2',
        'selling_price' => 'decimal:2',
    ];

    public function formula(): BelongsTo
    {
        return $this->belongsTo(Formula::class);
    }
}
