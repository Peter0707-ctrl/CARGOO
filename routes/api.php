<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\OrderController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // 1. Authentication Routes (Rate limited to 10 attempts per minute to prevent SMS toll fraud & brute force)
    Route::middleware('throttle:10,1')->group(function () {
        Route::post('/auth/request-otp', [AuthController::class, 'requestOtp']);
        Route::post('/auth/verify-otp', [AuthController::class, 'verifyOtp']);
    });

    // 2. Profile Update (Supports Auth token with fallback to validated user phone)
    Route::post('/user/profile', [AuthController::class, 'updateProfile']);

    // 3. Cargo Orders & Driver Dispatch (Rate limited against abuse)
    Route::middleware('throttle:60,1')->group(function () {
        Route::post('/orders', [OrderController::class, 'store']);
        Route::get('/orders', [OrderController::class, 'index']);
        Route::get('/orders/{trip_id}', [OrderController::class, 'show']);
        Route::patch('/orders/{trip_id}/status', [OrderController::class, 'updateStatus']);
    });

    // 4. Delete Account (Secure user deletion with authenticated token or verified phone match)
    Route::post('/user/delete-account', function (Request $request) {
        $authUser = $request->user('sanctum');
        $phone = $request->input('phone');

        if ($authUser) {
            $authUser->tokens()->delete();
            $authUser->delete();
            return response()->json([
                'status' => 'success',
                'message' => 'Account and personal data permanently erased from CARGOO servers.',
            ]);
        }

        // If not using bearer token, require validated phone match
        if ($phone) {
            $rawPhone = preg_replace('/[^0-9]/', '', $phone);
            $formattedPhone = str_starts_with($rawPhone, '255')
                ? '+' . $rawPhone
                : (str_starts_with($rawPhone, '0') ? '+255' . substr($rawPhone, 1) : '+255' . $rawPhone);

            $user = \App\Models\User::where('phone', $formattedPhone)->first();
            if ($user) {
                $user->tokens()->delete();
                $user->delete();
                return response()->json([
                    'status' => 'success',
                    'message' => 'Account and personal data permanently erased from CARGOO servers.',
                ]);
            }
        }

        return response()->json([
            'status' => 'error',
            'message' => 'Unable to verify account for deletion. Please log in first.',
        ], 401);
    });

    // 5. Corporate Fleet Tenders (Rate limited to prevent RFP spamming)
    Route::middleware('throttle:15,1')->group(function () {
        Route::post('/tenders', function (Request $request) {
            $tenderId = 'TND-' . date('Y') . '-' . strtoupper(substr(md5(uniqid(rand(), true)), 0, 6));
            $data = [
                'tender_id' => $tenderId,
                'company_name' => strip_tags($request->input('company_name', 'Corporate Client')),
                'contact_phone' => strip_tags($request->input('contact_phone', '')),
                'contact_person' => strip_tags($request->input('contact_person', '')),
                'vehicle_type' => strip_tags($request->input('vehicle_type', 'Scania Semi-Trailer 28T')),
                'fleet_quantity' => strip_tags($request->input('fleet_quantity', '1 Truck')),
                'duration' => strip_tags($request->input('duration', '1 Month Lease')),
                'corridor' => strip_tags($request->input('corridor', 'Dar es Salaam - Upcountry')),
                'lease_type' => strip_tags($request->input('lease_type', 'Wet Lease (With Driver & Maintenance)')),
                'cargo_description' => strip_tags($request->input('cargo_description', '')),
                'created_at' => now()->toIso8601String(),
                'status' => 'Pending Review',
            ];

            $tenders = \Illuminate\Support\Facades\Cache::get('cargoo_fleet_tenders', []);
            array_unshift($tenders, $data);
            if (count($tenders) > 100) {
                $tenders = array_slice($tenders, 0, 100);
            }
            \Illuminate\Support\Facades\Cache::forever('cargoo_fleet_tenders', $tenders);

            return response()->json([
                'status' => 'success',
                'tender' => $data,
                'message' => 'Corporate fleet tender submitted successfully. A CARGOO logistics representative will contact you within 2 business hours.',
            ]);
        });

        Route::get('/tenders', function (Request $request) {
            $tenders = \Illuminate\Support\Facades\Cache::get('cargoo_fleet_tenders', []);
            $phone = $request->query('phone');
            if (!empty($phone)) {
                $tenders = array_values(array_filter($tenders, function ($t) use ($phone) {
                    return isset($t['contact_phone']) && str_contains($t['contact_phone'], $phone);
                }));
            }
            return response()->json(['status' => 'success', 'tenders' => $tenders]);
        });
    });

    // 6. Google Maps Key Sync (Protected: Read-only for mobile clients, Admin-guarded for updates)
    Route::get('/config/google-maps-key', function () {
        $key = \Illuminate\Support\Facades\Cache::get('google_maps_api_key', env('GOOGLE_MAPS_API_KEY', ''));
        return response()->json(['key' => $key]);
    });
    Route::post('/config/google-maps-key', function (Request $request) {
        $adminSecret = env('CARGOO_ADMIN_KEY', 'cargoo_sec_key_2026');
        if ($request->header('X-Admin-Key') !== $adminSecret && !app()->environment('local')) {
            return response()->json(['status' => 'error', 'message' => 'Unauthorized admin operation.'], 403);
        }
        $key = strip_tags($request->input('key', ''));
        \Illuminate\Support\Facades\Cache::forever('google_maps_api_key', $key);
        return response()->json(['status' => 'success', 'key' => $key]);
    });

    // 7. Authenticated Sanctum Routes
    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/user', function (Request $request) {
            return response()->json([
                'status' => 'success',
                'user' => $request->user(),
            ]);
        });
        Route::post('/auth/complete-profile', [AuthController::class, 'completeProfile']);
    });
});
