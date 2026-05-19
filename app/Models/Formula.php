<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['code', 'name', 'batch_size', 'status', 'rnd_approved_by', 'rnd_approved_at', 'created_by'])]
class Formula extends Model
{
    protected $casts = [
        'batch_size' => 'decimal:4',
        'rnd_approved_at' => 'datetime',
    ];

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function approver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'rnd_approved_by');
    }

    public function ingredients(): HasMany
    {
        return $this->hasMany(FormulaIngredient::class);
    }

    public function costs(): HasMany
    {
        return $this->hasMany(FormulaCost::class);
    }

    public function hpp(): HasOne
    {
        return $this->hasOne(HppCalculation::class);
    }
}
