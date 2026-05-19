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
        Schema::create('formulas', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->string('name');
            $table->decimal('batch_size', 15, 4); // Target size in standard master unit
            $table->enum('status', ['draft', 'approved', 'revised'])->default('draft');
            $table->foreignId('rnd_approved_by')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamp('rnd_approved_at')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamps();
        });

        Schema::create('formula_ingredients', function (Blueprint $table) {
            $table->id();
            $table->foreignId('formula_id')->constrained('formulas')->onDelete('cascade');
            $table->foreignId('ingredient_id')->constrained('ingredients')->onDelete('cascade');
            $table->decimal('quantity_per_batch', 15, 4);
            $table->enum('unit', ['g', 'kg', 'ml', 'l', 'pcs']);
            $table->decimal('unit_price', 15, 2); // Snapshot price at creation
            $table->decimal('subtotal', 15, 2);
            $table->timestamps();
        });

        Schema::create('formula_costs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('formula_id')->constrained('formulas')->onDelete('cascade');
            $table->enum('type', ['labor', 'overhead', 'other']);
            $table->string('description');
            $table->decimal('cost_value', 15, 2);
            $table->timestamps();
        });

        Schema::create('hpp_calculations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('formula_id')->constrained('formulas')->onDelete('cascade');
            $table->decimal('total_ingredient_cost', 15, 2);
            $table->decimal('total_labor_cost', 15, 2);
            $table->decimal('total_overhead_cost', 15, 2);
            $table->decimal('total_other_cost', 15, 2);
            $table->decimal('total_hpp', 15, 2);
            $table->decimal('hpp_per_unit', 15, 2);
            $table->decimal('profit_margin_percent', 5, 2)->default(0);
            $table->decimal('selling_price', 15, 2)->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('hpp_calculations');
        Schema::dropIfExists('formula_costs');
        Schema::dropIfExists('formula_ingredients');
        Schema::dropIfExists('formulas');
    }
};
