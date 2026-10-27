<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Order extends Model
{
    use HasFactory;

    protected $fillable = [
        'trip_id',
        'customer_id',
        'customer_name',
        'customer_phone',
        'customer_avatar',
        'customer_nida',
        'sender_name',
        'sender_phone',
        'recipient_name',
        'recipient_phone',
        'pickup_name',
        'pickup_lat',
        'pickup_lng',
        'dropoff_name',
        'dropoff_lat',
        'dropoff_lng',
        'vehicle_type',
        'vehicle_id',
        'fare_amount',
        'distance_km',
        'duration_minutes',
        'cargo_notes',
        'payment_method',
        'is_scheduled',
        'scheduled_for',
        'status',
        'driver_name',
        'driver_phone',
        'driver_plate',
    ];

    protected function casts(): array
    {
        return [
            'is_scheduled' => 'boolean',
            'pickup_lat' => 'float',
            'pickup_lng' => 'float',
            'dropoff_lat' => 'float',
            'dropoff_lng' => 'float',
            'duration_minutes' => 'integer',
        ];
    }

    public function customer()
    {
        return $this->belongsTo(User::class, 'customer_id');
    }
}
