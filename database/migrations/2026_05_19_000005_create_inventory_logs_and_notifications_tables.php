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
        Schema::create('inventory_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ingredient_id')->constrained('ingredients')->onDelete('cascade');
            $table->enum('type', ['in', 'out', 'adjustment', 'production_release']);
            $table->decimal('quantity', 15, 4);
            $table->enum('unit', ['g', 'kg', 'ml', 'l', 'pcs']);
            $table->decimal('balance_after', 15, 4); // Standard base unit balance
            $table->string('reference_type')->nullable(); // e.g. PurchaseOrder, MaterialRequest, Adjustment
            $table->bigInteger('reference_id')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('user_id')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamps();
        });

        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('type'); // restock_alert, material_request, rnd_approval, etc.
            $table->string('title');
            $table->text('message');
            $table->timestamp('read_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('inventory_logs');
    }
};
