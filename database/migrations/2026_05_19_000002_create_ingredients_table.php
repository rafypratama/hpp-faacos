<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('ingredients', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->string('name');
            $table->enum('type', ['raw_material', 'packaging']);
            $table->enum('unit', ['g', 'kg', 'ml', 'l', 'pcs']);
            $table->decimal('price_per_unit', 15, 2);
            $table->decimal('current_stock', 15, 4)->default(0);
            $table->decimal('minimum_stock', 15, 4)->default(0);
            $table->date('expired_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ingredients');
    }
};
