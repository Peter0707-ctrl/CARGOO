<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class AuthController extends Controller
{
    /**
     * Request OTP for login or registration.
     */
    public function requestOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => 'required|string',
        ]);

        $rawPhone = preg_replace('/[^0-9]/', '', $validated['phone']);

        // Normalize Tanzania phone numbers
        if (str_starts_with($rawPhone, '255')) {
            $formattedPhone = '+' . $rawPhone;
        } elseif (str_starts_with($rawPhone, '0')) {
            $formattedPhone = '+255' . substr($rawPhone, 1);
        } else {
            $formattedPhone = '+255' . $rawPhone;
        }

        // Generate cryptographically secure 4-digit OTP
        $otp = (string) random_int(1000, 9999);
        $expiresAt = Carbon::now()->addMinutes(10);

        $user = User::firstOrCreate(
            ['phone' => $formattedPhone],
            [
                'role' => 'customer',
                'city' => 'Dar es Salaam',
                'is_verified' => false,
            ]
        );

        $user->otp_code = hash('sha256', $otp);
        $user->otp_expires_at = $expiresAt;
        $user->save();

        Log::info("CARGOO OTP sent to {$formattedPhone}: {$otp}");

        $response = [
            'status' => 'success',
            'message' => 'Nambari ya uthibitisho (OTP) imetumwa kikamilifu.',
            'phone' => $formattedPhone,
            'expires_in_seconds' => 600,
        ];

        // Safe dev inspection only in local environment
        if (config('app.debug') && app()->environment('local')) {
            $response['debug_otp'] = $otp;
        }

        return response()->json($response);
    }

    /**
     * Verify OTP and issue Sanctum token.
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => 'required|string',
            'otp_code' => 'required|string|min:4|max:6',
        ]);

        $rawPhone = preg_replace('/[^0-9]/', '', $validated['phone']);
        if (str_starts_with($rawPhone, '255')) {
            $formattedPhone = '+' . $rawPhone;
        } elseif (str_starts_with($rawPhone, '0')) {
            $formattedPhone = '+255' . substr($rawPhone, 1);
        } else {
            $formattedPhone = '+255' . $rawPhone;
        }

        $user = User::where('phone', $formattedPhone)->first();

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'Namba ya simu haijapatikana. Tafadhali omba OTP upya.',
            ], 404);
        }

        // Securely verify hashed OTP (with local dev bypass only if explicitly local and debug)
        $inputHash = hash('sha256', $validated['otp_code']);
        $isLocalDevBypass = config('app.debug') && app()->environment('local') && in_array($validated['otp_code'], ['1234', '123456'], true);
        $isMatch = hash_equals($user->otp_code ?? '', $inputHash) || $isLocalDevBypass;
        $isExpired = $user->otp_expires_at && Carbon::now()->isAfter($user->otp_expires_at);

        if (!$isMatch || $isExpired) {
            return response()->json([
                'status' => 'error',
                'message' => 'Nambari ya OTP sio sahihi au imekwisha muda wake.',
            ], 422);
        }

        $user->is_verified = true;
        $user->otp_code = null;
        $user->otp_expires_at = null;
        $user->save();

        $token = $user->createToken('cargoo_mobile_token')->plainTextToken;

        return response()->json([
            'status' => 'success',
            'message' => 'Umefanikiwa kuingia kikamilifu.',
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'phone' => $user->phone,
                'email' => $user->email,
                'role' => $user->role,
                'city' => $user->city,
                'is_profile_complete' => !empty($user->name),
            ],
        ]);
    }

    /**
     * Complete user profile details.
     */
    public function completeProfile(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'nida_number' => 'nullable|string|max:30',
            'email' => 'nullable|email|max:150',
            'city' => 'nullable|string|max:100',
            'avatar_url' => 'nullable|string',
        ]);

        $user = $request->user();
        $user->name = $validated['name'];
        if (isset($validated['nida_number'])) {
            $user->nida_number = $validated['nida_number'];
        }
        if (isset($validated['email'])) {
            $user->email = $validated['email'];
        }
        if (isset($validated['city'])) {
            $user->city = $validated['city'];
        }
        if (isset($validated['avatar_url'])) {
            $user->avatar_url = $validated['avatar_url'];
        }
        $user->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Profile updated successfully.',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'phone' => $user->phone,
                'nida_number' => $user->nida_number,
                'email' => $user->email,
                'role' => $user->role,
                'city' => $user->city,
                'avatar_url' => $user->avatar_url,
                'is_profile_complete' => true,
            ],
        ]);
    }

    /**
     * Update user profile & avatar (accessible via auth token or phone).
     */
    public function updateProfile(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => 'nullable|string',
            'name' => 'required|string|max:100',
            'email' => 'nullable|email|max:150',
            'nida_number' => 'nullable|string|max:40',
            'city' => 'nullable|string|max:100',
            'avatar_url' => 'nullable|string',
        ]);

        $user = $request->user();
        if (!$user && !empty($validated['phone'])) {
            $rawPhone = preg_replace('/[^0-9]/', '', $validated['phone']);
            if (str_starts_with($rawPhone, '255')) {
                $formattedPhone = '+' . $rawPhone;
            } elseif (str_starts_with($rawPhone, '0')) {
                $formattedPhone = '+255' . substr($rawPhone, 1);
            } else {
                $formattedPhone = '+255' . $rawPhone;
            }
            $user = User::where('phone', $formattedPhone)->first();
        }

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'User profile not found. Please log in first.',
            ], 404);
        }

        $user->name = $validated['name'];
        if (isset($validated['email'])) $user->email = $validated['email'];
        if (isset($validated['nida_number'])) $user->nida_number = $validated['nida_number'];
        if (isset($validated['city'])) $user->city = $validated['city'];
        if (isset($validated['avatar_url'])) $user->avatar_url = $validated['avatar_url'];
        $user->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Profile and photo updated successfully.',
            'user' => $user ? [
                'id' => $user->id,
                'name' => $user->name,
                'phone' => $user->phone,
                'nida_number' => $user->nida_number,
                'email' => $user->email,
                'role' => $user->role,
                'city' => $user->city,
                'avatar_url' => $user->avatar_url,
                'is_profile_complete' => true,
            ] : null,
        ]);
    }
}
