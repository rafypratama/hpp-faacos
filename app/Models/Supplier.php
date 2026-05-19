<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['code', 'name', 'contact_person', 'phone', 'email', 'address', 'status'])]
class Supplier extends Model
{
    protected $casts = [
        'status' => 'boolean',
    ];
}
