<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class OrderController extends Controller
{
    /**
     * Store newly dispatched cargo order from mobile app.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'trip_id' => 'required|string',
            'customer_name' => 'required|string|max:150',
            'customer_phone' => 'required|string|max:30',
            'customer_avatar' => 'nullable|string',
            'customer_nida' => 'nullable|string|max:40',
            'sender_name' => 'nullable|string|max:150',
            'sender_phone' => 'nullable|string|max:30',
            'recipient_name' => 'nullable|string|max:150',
            'recipient_phone' => 'nullable|string|max:30',
            'pickup_name' => 'required|string',
            'pickup_lat' => 'required|numeric',
            'pickup_lng' => 'required|numeric',
            'dropoff_name' => 'required|string',
            'dropoff_lat' => 'required|numeric',
            'dropoff_lng' => 'required|numeric',
            'vehicle_type' => 'required|string',
            'vehicle_id' => 'required|string',
            'fare_amount' => 'required|string',
            'distance_km' => 'required|string',
            'duration_minutes' => 'nullable|integer',
            'cargo_notes' => 'nullable|string',
            'payment_method' => 'nullable|string',
            'is_scheduled' => 'nullable|boolean',
            'scheduled_for' => 'nullable|string',
            'driver_name' => 'nullable|string',
            'driver_phone' => 'nullable|string',
            'driver_plate' => 'nullable|string',
        ]);

        // Link with existing user if available
        $user = User::where('phone', $validated['customer_phone'])->first();
        if ($user) {
            $validated['customer_id'] = $user->id;
            if (empty($validated['customer_avatar']) && !empty($user->avatar_url)) {
                $validated['customer_avatar'] = $user->avatar_url;
            }
            if (empty($validated['customer_nida']) && !empty($user->nida_number)) {
                $validated['customer_nida'] = $user->nida_number;
            }
        }

        $order = Order::updateOrCreate(
            ['trip_id' => $validated['trip_id']],
            $validated
        );

        Log::info("CARGOO Dispatched Order #{$order->trip_id} from Customer: {$order->customer_name} ({$order->customer_phone}) to Driver: {$order->driver_name} ({$order->driver_phone})");

        return response()->json([
            'status' => 'success',
            'message' => 'Cargo order dispatched successfully to driver account.',
            'order' => $order,
        ], 201);
    }

    /**
     * List all cargo orders (Driver Feed).
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Order::query();

        if ($user) {
            // Customers only see their own cargo orders
            if ($user->role === 'customer') {
                $query->where(function ($q) use ($user) {
                    $q->where('customer_id', $user->id)
                      ->orWhere('customer_phone', $user->phone);
                });
            }
        } elseif ($request->filled('phone')) {
            $query->where('customer_phone', $request->input('phone'));
        }

        $orders = $query->orderBy('created_at', 'desc')->take(30)->get();

        return response()->json([
            'status' => 'success',
            'count' => $orders->count(),
            'orders' => $orders,
        ]);
    }

    /**
     * Retrieve single order details.
     */
    public function show($tripId): JsonResponse
    {
        $order = Order::where('trip_id', $tripId)->orWhere('id', $tripId)->first();

        if (!$order) {
            return response()->json([
                'status' => 'error',
                'message' => 'Order not found.',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'order' => $order,
        ]);
    }

    /**
     * Update order status by driver (Accept, Start Transit, Complete).
     */
    public function updateStatus(Request $request, $tripId): JsonResponse
    {
        $order = Order::where('trip_id', $tripId)->orWhere('id', $tripId)->firstOrFail();

        $validated = $request->validate([
            'status' => 'required|string|in:driver_assigned,accepted,en_route,delivered,cancelled',
        ]);

        $order->status = $validated['status'];
        $order->save();

        return response()->json([
            'status' => 'success',
            'message' => "Order status updated to {$order->status}.",
            'order' => $order,
        ]);
    }
}
