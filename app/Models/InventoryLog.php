<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['ingredient_id', 'type', 'quantity', 'unit', 'balance_after', 'reference_type', 'reference_id', 'notes', 'user_id'])]
class InventoryLog extends Model
{
    protected $casts = [
        'quantity' => 'decimal:4',
        'balance_after' => 'decimal:4',
    ];

    public function ingredient(): BelongsTo
    {
        return $this->belongsTo(Ingredient::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
