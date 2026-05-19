<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['material_request_id', 'ingredient_id', 'quantity_required', 'unit', 'quantity_approved'])]
class MaterialRequestItem extends Model
{
    protected $casts = [
        'quantity_required' => 'decimal:4',
        'quantity_approved' => 'decimal:4',
    ];

    public function materialRequest(): BelongsTo
    {
        return $this->belongsTo(MaterialRequest::class);
    }

    public function ingredient(): BelongsTo
    {
        return $this->belongsTo(Ingredient::class);
    }
}
