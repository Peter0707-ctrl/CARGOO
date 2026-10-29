<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class AuthController extends Controller
{
    /**
     * Strictly normalize any Tanzania phone variation into standard E.164: +255XXXXXXXXX
     * Handles 06..., 07..., 255..., +255..., 2550... flawlessly.
     */
    public static function normalizeTanzaniaPhone(string $input): string
    {
        $digits = preg_replace('/[^0-9]/', '', $input);
        if (strlen($digits) >= 9) {
            $last9 = substr($digits, -9);
            return '+255' . $last9;
        }
        return '+255' . $digits;
    }

    /**
     * Request OTP for login or registration.
     */
    public function requestOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => 'required|string',
        ]);

        $formattedPhone = self::normalizeTanzaniaPhone($validated['phone']);

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
        $this->dispatchRealSmsOtp($formattedPhone, $otp);

        $response = [
            'status' => 'success',
            'message' => 'Nambari ya uthibitisho (OTP) imetumwa kikamilifu.',
            'phone' => $formattedPhone,
            'expires_in_seconds' => 600,
        ];

        return response()->json($response);
    }

    /**
     * Dispatch real SMS via Africa's Talking SMS Gateway (and fallback carriers)
     * and push live Android OS notification when testing over USB.
     */
    private function dispatchRealSmsOtp(string $phone, string $otp): void
    {
        $message = "CARGOO: Namba yako ya uthibitisho (OTP) ni {$otp}. Inatumika kwa dakika 10. Usitoe namba hii kwa mtu yeyote.";
        $cleanPhone = ltrim($phone, '+');

        // 0. Beem Africa SMS Gateway (Tanzania Primary Carrier)
        $beemApiKey = env('BEEM_API_KEY');
        $beemSecretKey = env('BEEM_SECRET_KEY');
        $beemSender = env('BEEM_SENDER_NAME', 'Tukio360');

        if (!empty($beemApiKey) && !empty($beemSecretKey)) {
            try {
                $auth = base64_encode("{$beemApiKey}:{$beemSecretKey}");
                $payload = [
                    'source_addr' => $beemSender,
                    'schedule_time' => '',
                    'encoding' => 0,
                    'message' => $message,
                    'recipients' => [
                        [
                            'recipient_id' => 1,
                            'dest_addr' => $cleanPhone,
                        ]
                    ]
                ];

                $response = Http::withHeaders([
                    'Authorization' => "Basic {$auth}",
                    'Content-Type' => 'application/json',
                ])
                ->timeout(5)
                ->post('https://apisms.beem.africa/v1/send', $payload);

                Log::info("Beem Africa SMS dispatch to {$cleanPhone}: HTTP " . $response->status() . " Body: " . $response->body());
            } catch (\Throwable $e) {
                Log::warning("Beem Africa SMS dispatch error: " . $e->getMessage());
            }
        }

        // 1. Africa's Talking SMS Gateway
        $atApiKey = env('AFRICASTALKING_API_KEY');
        $atUsername = env('AFRICASTALKING_USERNAME', 'sandbox');
        $atEnv = env('AFRICASTALKING_ENV', 'sandbox');

        if (!empty($atApiKey)) {
            try {
                $endpoint = ($atEnv === 'sandbox' || $atUsername === 'sandbox')
                    ? 'https://api.sandbox.africastalking.com/version1/messaging'
                    : 'https://api.africastalking.com/version1/messaging';

                $payload = [
                    'username' => $atUsername,
                    'to' => $phone,
                    'message' => $message,
                ];

                $response = Http::asForm()
                    ->withHeaders([
                        'apiKey' => $atApiKey,
                        'Accept' => 'application/json',
                    ])
                    ->timeout(5)
                    ->post($endpoint, $payload);

                Log::info("Africa's Talking SMS dispatch status: " . $response->status() . " Body: " . $response->body());
            } catch (\Throwable $e) {
                Log::warning("Africa's Talking SMS error: " . $e->getMessage());
            }
        }

        // 2. NextSMS Gateway (Tanzania fallback)
        $nextSmsToken = env('NEXTSMS_TOKEN');
        if (!empty($nextSmsToken)) {
            try {
                Http::withToken($nextSmsToken)
                    ->timeout(4)
                    ->post('https://messaging-service.co.tz/api/sms/v1/text/single', [
                        'from' => env('NEXTSMS_SENDER_ID', 'CARGOO'),
                        'to' => $cleanPhone,
                        'text' => $message,
                    ]);
            } catch (\Throwable $e) {
                Log::warning("NextSMS error: " . $e->getMessage());
            }
        }

        // 3. Local USB Android OS Real Notification Delivery
        if (app()->environment('local')) {
            try {
                $escapedMsg = addslashes($message);
                @pclose(@popen("start /B adb shell \"cmd notification post -S bigtext -t 'CARGOO SMS' 'cargoo_otp' '{$escapedMsg}'\" >NUL 2>&1", "r"));
            } catch (\Throwable $e) {
                // Ignore if adb is not attached
            }
        }
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

        $formattedPhone = self::normalizeTanzaniaPhone($validated['phone']);

        $user = User::where('phone', $formattedPhone)->first();

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'Namba ya simu haijapatikana. Tafadhali omba OTP upya.',
            ], 404);
        }

        // Strictly verify hashed OTP with timing attack resistance
        $inputHash = hash('sha256', $validated['otp_code']);
        $isMatch = hash_equals($user->otp_code ?? '', $inputHash);
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
            $formattedPhone = self::normalizeTanzaniaPhone($validated['phone']);
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
