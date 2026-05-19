<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['code', 'name', 'type', 'unit', 'price_per_unit', 'current_stock', 'minimum_stock', 'expired_at'])]
class Ingredient extends Model
{
    protected $casts = [
        'price_per_unit' => 'decimal:2',
        'current_stock' => 'decimal:4',
        'minimum_stock' => 'decimal:4',
        'expired_at' => 'date',
    ];

    public function inventoryLogs(): HasMany
    {
        return $this->hasMany(InventoryLog::class);
    }
}
