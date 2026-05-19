<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['code', 'formula_id', 'target_quantity', 'batch_count', 'status', 'scheduled_start_date', 'scheduled_end_date', 'created_by'])]
class ProductionOrder extends Model
{
    protected $casts = [
        'target_quantity' => 'decimal:4',
        'batch_count' => 'integer',
        'scheduled_start_date' => 'date',
        'scheduled_end_date' => 'date',
    ];

    public function formula(): BelongsTo
    {
        return $this->belongsTo(Formula::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function materialRequest(): HasOne
    {
        return $this->hasOne(MaterialRequest::class);
    }
}
