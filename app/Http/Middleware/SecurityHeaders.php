<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SecurityHeaders
{
    /**
     * Handle an incoming request and enforce robust HTTP security headers.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Remove server execution signature from PHP engine if possible
        if (function_exists('header_remove')) {
            @header_remove('X-Powered-By');
            @header_remove('Server');
        }

        /** @var Response $response */
        $response = $next($request);

        // Remove response headers that leak server technologies
        $response->headers->remove('X-Powered-By');
        $response->headers->remove('Server');

        // 1. Prevent Clickjacking
        $response->headers->set('X-Frame-Options', 'SAMEORIGIN');

        // 2. Prevent MIME type sniffing
        $response->headers->set('X-Content-Type-Options', 'nosniff');

        // 3. XSS Filter Protection
        $response->headers->set('X-XSS-Protection', '1; mode=block');

        // 4. Referrer Policy (Strict origin to avoid leaking sensitive query params/URLs)
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');

        // 5. Strict Transport Security (HSTS - 1 year, include subdomains)
        if ($request->isSecure() || app()->environment('production')) {
            $response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
        }

        // 6. Permissions-Policy (Restrict hardware and sensors by default)
        $response->headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(self), payment=(self), usb=()');

        // 7. Content-Security-Policy (CSP)
        $csp = "default-src 'self'; script-src 'self' 'unsafe-inline' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' data: https:; connect-src 'self' https: wss:; frame-ancestors 'self'; form-action 'self'; base-uri 'self'; object-src 'none';";
        $response->headers->set('Content-Security-Policy', $csp);

        // 8. Cross-Origin Policies
        $response->headers->set('Cross-Origin-Opener-Policy', 'same-origin-allow-popups');
        $response->headers->set('Cross-Origin-Resource-Policy', 'cross-origin');

        // 9. Cache-Control for sensitive API endpoints
        if ($request->is('api/*')) {
            if ($request->is('api/v1/auth/*') || $request->is('api/v1/user/*') || $request->is('api/v1/driver/wallet/*')) {
                $response->headers->set('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0, private');
                $response->headers->set('Pragma', 'no-cache');
            }
        }

        return $response;
    }
}
