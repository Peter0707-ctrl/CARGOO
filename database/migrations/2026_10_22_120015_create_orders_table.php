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
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('trip_id')->unique();
            $table->foreignId('customer_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('customer_name');
            $table->string('customer_phone');
            $table->string('customer_avatar')->nullable();
            $table->string('customer_nida')->nullable();
            $table->string('sender_name')->default('Myself');
            $table->string('sender_phone')->nullable();
            $table->string('recipient_name')->nullable();
            $table->string('recipient_phone')->nullable();
            $table->string('pickup_name');
            $table->decimal('pickup_lat', 10, 7);
            $table->decimal('pickup_lng', 10, 7);
            $table->string('dropoff_name');
            $table->decimal('dropoff_lat', 10, 7);
            $table->decimal('dropoff_lng', 10, 7);
            $table->string('vehicle_type');
            $table->string('vehicle_id');
            $table->string('fare_amount');
            $table->string('distance_km');
            $table->integer('duration_minutes')->default(10);
            $table->text('cargo_notes')->nullable();
            $table->string('payment_method')->default('Cash Payment');
            $table->boolean('is_scheduled')->default(false);
            $table->string('scheduled_for')->nullable();
            $table->string('status')->default('driver_assigned');
            $table->string('driver_name')->default('Ally Mussa');
            $table->string('driver_phone')->default('0714 882 109');
            $table->string('driver_plate')->default('T 842 DFX');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
