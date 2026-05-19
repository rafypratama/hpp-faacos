<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Request;

class AuditLog extends Model
{
    protected $fillable = [
        'user_id',
        'action',
        'model_type',
        'model_id',
        'description',
        'details',
        'ip_address'
    ];

    protected $casts = [
        'details' => 'array'
    ];

    /**
     * Relationship with the user who triggered the action.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Static helper to cleanly write audit logs.
     */
    public static function logAction(?int $userId, string $action, string $description, ?Model $model = null, ?array $details = null): self
    {
        return self::create([
            'user_id' => $userId,
            'action' => $action,
            'description' => $description,
            'model_type' => $model ? get_class($model) : null,
            'model_id' => $model ? $model->getKey() : null,
            'details' => $details,
            'ip_address' => Request::ip()
        ]);
    }
}
