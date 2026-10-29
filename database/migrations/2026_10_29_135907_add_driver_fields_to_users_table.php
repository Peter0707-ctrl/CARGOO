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
        Schema::table('users', function (Blueprint $table) {
            $table->string('vehicle_type')->nullable()->after('role');
            $table->string('vehicle_plate')->nullable()->after('vehicle_type');
            $table->string('license_number')->nullable()->after('vehicle_plate');
            $table->boolean('is_online')->default(false)->after('license_number');
            $table->decimal('current_lat', 10, 7)->nullable()->after('is_online');
            $table->decimal('current_lng', 10, 7)->nullable()->after('current_lat');
            $table->decimal('rating', 3, 2)->default(5.00)->after('current_lng');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'vehicle_type',
                'vehicle_plate',
                'license_number',
                'is_online',
                'current_lat',
                'current_lng',
                'rating',
            ]);
        });
    }
};
