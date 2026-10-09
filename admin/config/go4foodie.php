<?php

// App-specific settings (read via config('go4foodie.*') so `php artisan config:cache` works).
return [
    // Mobile JWT secret — must equal the Next.js admin's AUTH_SECRET.
    'auth_secret' => env('AUTH_SECRET'),

    // Public website origin; table QR codes encode <website_url>/order?table=<code>.
    'website_url' => env('WEBSITE_URL', 'http://localhost:3000'),

    // Shared image uploads folder (same as the Next admin so existing image URLs keep working).
    'upload_dir' => env('UPLOAD_DIR'),

    'floor_stream_max_seconds' => (int) env('FLOOR_STREAM_MAX_SECONDS', 120),

    'razorpay' => [
        'key_id' => env('RAZORPAY_KEY_ID', ''),
        'key_secret' => env('RAZORPAY_KEY_SECRET', ''),
        'currency' => env('RAZORPAY_CURRENCY', 'INR'),
    ],
    'stripe' => [
        'secret_key' => env('STRIPE_SECRET_KEY', ''),
        'publishable_key' => env('STRIPE_PUBLISHABLE_KEY', ''),
        'currency' => env('STRIPE_CURRENCY', 'usd'),
    ],
    'paypal' => [
        'client_id' => env('PAYPAL_CLIENT_ID', ''),
        'client_secret' => env('PAYPAL_CLIENT_SECRET', ''),
        'currency' => env('PAYPAL_CURRENCY', 'USD'),
        'env' => env('PAYPAL_ENV', 'sandbox'),
    ],
];
