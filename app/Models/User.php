<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'phone',
        'nida_number',
        'email',
        'password',
        'role',
        'city',
        'otp_code',
        'otp_expires_at',
        'is_verified',
        'avatar_url',
        'vehicle_type',
        'vehicle_plate',
        'license_number',
        'is_online',
        'current_lat',
        'current_lng',
        'rating',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'otp_code',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'otp_expires_at' => 'datetime',
            'is_verified' => 'boolean',
            'password' => 'hashed',
        ];
    }
}
