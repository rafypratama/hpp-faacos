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
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users')->onDelete('set null');
            $table->string('action'); // e.g. login, logout, create_formula, approve_formula, schedule_production, verify_mr, adjust_stock
            $table->string('model_type')->nullable(); // e.g. App\Models\Formula
            $table->unsignedBigInteger('model_id')->nullable();
            $table->text('description'); // Human-readable description
            $table->json('details')->nullable(); // JSON representation of changes or payloads
            $table->string('ip_address')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};
