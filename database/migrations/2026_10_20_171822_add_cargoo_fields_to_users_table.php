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
            $table->string('name')->nullable()->change();
            $table->string('email')->nullable()->change();
            $table->string('password')->nullable()->change();

            $table->string('phone')->nullable()->unique()->after('id');
            $table->string('role')->default('customer')->after('phone'); // customer, driver, admin
            $table->string('otp_code', 10)->nullable()->after('role');
            $table->timestamp('otp_expires_at')->nullable()->after('otp_code');
            $table->boolean('is_verified')->default(false)->after('otp_expires_at');
            $table->string('city')->default('Dar es Salaam')->after('is_verified');
            $table->string('avatar_url')->nullable()->after('city');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'phone',
                'role',
                'otp_code',
                'otp_expires_at',
                'is_verified',
                'city',
                'avatar_url',
            ]);
        });
    }
};
