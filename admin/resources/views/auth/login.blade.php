<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Sign in · Go4Foodie Admin</title>
    <link rel="icon" href="/images/go4foodie-icon.png">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,600;9..144,700&family=Manrope:wght@400;500;600;700&display=swap" rel="stylesheet">
    <script>
        try { if (localStorage.getItem('admin-theme') === 'dark') document.documentElement.classList.add('dark'); } catch (e) {}
    </script>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body>
<main class="grid min-h-screen bg-bg lg:grid-cols-2">
    {{-- Brand panel --}}
    <div class="relative hidden overflow-hidden bg-[#0a1c18] lg:block">
        <video class="absolute inset-0 h-full w-full object-cover" autoplay loop muted playsinline preload="auto"
               poster="https://images.unsplash.com/photo-1577219491135-ce391730fb2c?auto=format&fit=crop&w=1400&q=80">
            <source src="/images/login-bg.mp4" type="video/mp4">
        </video>
        <div class="absolute inset-0 bg-gradient-to-t from-[#0a1c18] via-[#0a1c18]/70 to-[#0a1c18]/30"></div>
        <div class="absolute inset-0 bg-gradient-to-r from-transparent to-[#0a1c18]/40"></div>
        <div class="relative flex h-full flex-col justify-between p-12 text-white">
            <div><img src="/images/go4foodie-logo-wide-light.png" alt="Go4Foodie" class="h-16 w-auto"></div>
            <div class="max-w-lg">
                <span class="font-display text-6xl leading-none text-accent">&ldquo;</span>
                <blockquote class="-mt-6 font-display text-4xl font-medium leading-tight">
                    Great restaurants are run in the details — every plate, every table, every shift.
                </blockquote>
                <p class="mt-5 text-sm text-white/70">Your kitchen has the craft. This is where you run the business behind it.</p>
            </div>
            <ul class="space-y-3">
                @foreach (['Real-time orders, POS & reservations', 'Live analytics across every outlet', 'Menu, staff & inventory in one place'] as $h)
                    <li class="flex items-center gap-3 text-sm text-white/80"><span class="h-1.5 w-1.5 rounded-full bg-accent"></span>{{ $h }}</li>
                @endforeach
            </ul>
        </div>
    </div>

    {{-- Form --}}
    <div class="flex items-center justify-center px-6 py-12 sm:px-10">
        <div class="w-full max-w-sm">
            <div class="mb-8 lg:hidden">
                <span class="inline-flex rounded-xl bg-[#0a1c18] px-3.5 py-2.5"><img src="/images/go4foodie-logo-wide-light.png" alt="Go4Foodie" class="h-8 w-auto"></span>
            </div>
            <p class="text-sm font-semibold uppercase tracking-[0.2em] text-accent">Welcome back</p>
            <h1 class="mt-2 font-display text-3xl font-semibold">Sign in to your dashboard</h1>
            <p class="mt-2 text-sm text-fg-muted">Manage your restaurant &amp; team from one place.</p>

            <form method="POST" action="/login" class="mt-8 space-y-4" x-data="{ busy: false }" @submit="busy = true">
                @csrf
                @if (session('error'))
                    <p class="rounded-lg bg-danger-soft px-3 py-2 text-sm text-danger" role="alert">{{ session('error') }}</p>
                @endif
                <div>
                    <label for="email" class="label">Email</label>
                    <div class="relative">
                        <i data-lucide="mail" class="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                        <input id="email" name="email" type="email" autocomplete="email" value="{{ old('email') }}" required
                               class="input py-3 pl-11" placeholder="you@restaurant.com">
                    </div>
                    @error('email')<p class="mt-1 text-xs text-danger">{{ $message }}</p>@enderror
                </div>
                <div>
                    <label for="password" class="label">Password</label>
                    <div class="relative">
                        <i data-lucide="lock" class="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                        <input id="password" name="password" type="password" autocomplete="current-password" required
                               class="input py-3 pl-11" placeholder="••••••••">
                    </div>
                    @error('password')<p class="mt-1 text-xs text-danger">{{ $message }}</p>@enderror
                </div>
                <button type="submit" :disabled="busy" class="btn-primary group w-full py-3">
                    <span x-show="!busy" class="flex items-center gap-2">Sign in <i data-lucide="arrow-right" class="h-4 w-4 transition-transform group-hover:translate-x-0.5"></i></span>
                    <span x-show="busy" x-cloak>Signing in…</span>
                </button>
            </form>

            <p class="mt-6 rounded-lg border border-border bg-surface-2 px-3 py-2 text-center text-xs text-fg-muted">
                Demo · <span class="font-medium text-fg">george@merchant.test</span> / admin123
            </p>
        </div>
    </div>
</main>
</body>
</html>
