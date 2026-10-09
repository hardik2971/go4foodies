@php
    use App\Support\CurrentUser;

    $me = CurrentUser::get();
    $nav = [
        ['/dashboard', 'Overview', 'layout-grid', 'view:dashboard'],
        ['/orders', 'Orders', 'shopping-cart', 'manage:orders'],
        ['/menu', 'Menu', 'clipboard-list', 'manage:menu'],
        ['/reservations', 'Reservations', 'calendar-check', 'manage:reservations'],
        ['/tables', 'Tables', 'qr-code', 'manage:tables'],
        ['/floor', 'Floor', 'layout-dashboard', 'manage:tables'],
        ['/table-analytics', 'Table Analytics', 'activity', 'view:reports'],
        ['/staff', 'Staff', 'users', 'manage:staff'],
        ['/customers', 'Customers', 'contact', 'manage:customers'],
        ['/gift-cards', 'Gift Cards', 'gift', 'manage:coupons'],
        ['/transactions', 'Transactions', 'credit-card', 'view:reports'],
        ['/inventory', 'Inventory', 'package', 'manage:inventory'],
        ['/reports', 'Reports', 'bar-chart-3', 'view:reports'],
    ];
    $bottom = [['/audit', 'Audit Log', 'scroll-text', 'manage:settings']];

    $titles = [
        '/dashboard' => ['Overview', 'Manage your restaurant & team members from here.'],
        '/orders' => ['Orders', 'Track and manage every order across outlets.'],
        '/menu' => ['Menu', 'Manage dishes, categories, and availability.'],
        '/reservations' => ['Reservations', 'Table bookings & private events from your guests.'],
        '/floor' => ['Floor Plan', 'Live table status, sessions & occupancy.'],
        '/pos' => ['Point of Sale', 'Table billing, order entry & checkout.'],
        '/tables' => ['Table Management', 'QR codes for table-side ordering.'],
        '/outlets' => ['Outlets', 'Locations, managers, and operational metrics.'],
        '/staff' => ['Staff', 'Your team directory and duty status.'],
        '/customers' => ['Customers', 'Guest profiles, history, and lifetime value.'],
        '/gift-cards' => ['Gift Card & Coupon Management', 'Purchases, codes, and coupon status.'],
        '/transactions' => ['Transactions', 'Payments across orders, gift cards & tables.'],
        '/inventory' => ['Inventory', 'Stock levels and low-stock alerts.'],
        '/table-analytics' => ['Table Analytics', 'Sessions, occupancy & table performance.'],
        '/table-history' => ['Table History', 'Complete session timeline for a table.'],
        '/reports' => ['Reports', 'Analytics and exportable insights.'],
        '/notifications' => ['Notifications', 'Recent activity across the restaurant.'],
        '/audit' => ['Audit Log', 'Every POS & table action, who and when.'],
        '/settings' => ['Settings', 'Restaurant configuration and your profile.'],
    ];
    $path = '/'.ltrim(request()->path(), '/');
    $isActive = fn ($href) => $href === '/dashboard' ? $path === $href : str_starts_with($path, $href);
    [$title, $subtitle] = collect($titles)->first(fn ($v, $k) => $isActive($k)) ?? $titles['/dashboard'];
    $title = $pageTitle ?? $title;

    try {
        $attention = class_exists(\App\Services\Queries::class) ? \App\Services\Queries::getAttentionCount() : 0;
    } catch (\Throwable) {
        $attention = 0;
    }
    $roleLabel = ['OWNER' => 'Owner', 'MANAGER' => 'Manager', 'STAFF' => 'Staff'][$me['role'] ?? ''] ?? ($me['role'] ?? '');
    $initials = collect(explode(' ', $me['name'] ?? 'U'))->map(fn ($p) => mb_substr($p, 0, 1))->take(2)->implode('');
@endphp
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ $title }} · Go4Foodie Admin</title>
    <link rel="icon" href="/images/go4foodie-icon.png">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,600;9..144,700&family=Manrope:wght@400;500;600;700&display=swap" rel="stylesheet">
    {{-- Apply the saved theme before paint (same key as the Next.js admin). --}}
    <script>
        try { if (localStorage.getItem('admin-theme') === 'dark') document.documentElement.classList.add('dark'); } catch (e) {}
    </script>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
    @stack('head')
</head>
<body>
<div class="flex min-h-screen">
    {{-- Sidebar --}}
    <aside class="sticky top-0 flex h-screen w-[72px] shrink-0 flex-col items-center border-r border-border bg-surface py-5">
        <a href="/dashboard" aria-label="Go4Foodie" class="grid h-16 w-16 place-items-center">
            <img src="/images/go4foodie-logo.png" alt="Go4Foodie" class="h-auto w-full object-contain dark:hidden">
            <img src="/images/go4foodie-logo-light.png" alt="Go4Foodie" class="hidden h-auto w-full object-contain dark:block">
        </a>
        <nav class="mt-8 flex flex-1 flex-col items-center gap-2">
            @foreach ($nav as [$href, $label, $icon, $action])
                @if (CurrentUser::can($action))
                    <a href="{{ $href }}" title="{{ $label }}" aria-label="{{ $label }}" @if ($isActive($href)) aria-current="page" @endif
                       class="grid h-11 w-11 place-items-center rounded-xl transition-colors {{ $isActive($href) ? 'bg-accent text-white shadow-card' : 'text-fg-muted hover:bg-accent-soft hover:text-accent' }}">
                        <i data-lucide="{{ $icon }}" class="h-5 w-5"></i>
                    </a>
                @endif
            @endforeach
        </nav>
        <div class="flex flex-col items-center gap-2">
            @foreach ($bottom as [$href, $label, $icon, $action])
                @if (CurrentUser::can($action))
                    <a href="{{ $href }}" title="{{ $label }}" aria-label="{{ $label }}"
                       class="grid h-11 w-11 place-items-center rounded-xl transition-colors {{ $isActive($href) ? 'bg-accent text-white shadow-card' : 'text-fg-muted hover:bg-accent-soft hover:text-accent' }}">
                        <i data-lucide="{{ $icon }}" class="h-5 w-5"></i>
                    </a>
                @endif
            @endforeach
        </div>
    </aside>

    <div class="flex min-w-0 flex-1 flex-col">
        {{-- Topbar --}}
        <header class="sticky top-0 z-20 flex items-center gap-4 border-b border-border bg-bg/80 px-6 py-4 backdrop-blur">
            <div class="min-w-0">
                <h1 class="font-display text-2xl font-semibold leading-tight">{{ $title }}</h1>
                <p class="truncate text-sm text-fg-muted">{{ $pageSubtitle ?? $subtitle }}</p>
            </div>

            <form action="{{ request()->url() }}" method="GET" class="relative mx-auto hidden w-full max-w-xl md:block">
                <i data-lucide="search" class="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input name="q" value="{{ request('q') }}" placeholder="type here to search anything"
                       class="w-full rounded-xl border border-border bg-surface py-2.5 pl-11 pr-16 text-sm outline-none transition-colors focus:border-accent">
                <kbd class="absolute right-3 top-1/2 -translate-y-1/2 rounded-md border border-border bg-bg px-1.5 py-0.5 text-[11px] font-medium text-fg-muted">⌘F</kbd>
            </form>

            <div class="ml-auto flex items-center gap-2">
                <button type="button" onclick="toggleTheme()" title="Toggle theme" aria-label="Toggle theme"
                        class="grid h-10 w-10 place-items-center rounded-xl text-fg-muted transition-colors hover:bg-surface hover:text-fg">
                    <i data-lucide="moon" class="h-5 w-5 dark:hidden"></i>
                    <i data-lucide="sun" class="hidden h-5 w-5 dark:block"></i>
                </button>
                <a href="/notifications" aria-label="Notifications"
                   class="relative grid h-10 w-10 place-items-center rounded-xl text-fg-muted transition-colors hover:bg-surface hover:text-fg">
                    <i data-lucide="bell" class="h-5 w-5"></i>
                    @if ($attention > 0)
                        <span class="absolute right-1.5 top-1.5 grid h-4 min-w-4 place-items-center rounded-full bg-accent px-1 text-[10px] font-semibold text-white">{{ $attention > 9 ? '9+' : $attention }}</span>
                    @endif
                </a>
                <div class="relative" x-data="{ open: false }" @click.outside="open = false">
                    <button type="button" @click="open = !open" class="flex items-center gap-3 rounded-xl px-1.5 py-1 transition-colors hover:bg-surface">
                        <span class="grid h-10 w-10 place-items-center rounded-full bg-accent-soft text-sm font-semibold text-accent">{{ $initials }}</span>
                        <span class="hidden text-left leading-tight sm:block">
                            <span class="block text-sm font-semibold">{{ $me['name'] ?? '' }}</span>
                            <span class="block text-xs text-fg-muted">{{ $roleLabel }}</span>
                        </span>
                        <i data-lucide="chevron-down" class="hidden h-4 w-4 text-fg-muted sm:block"></i>
                    </button>
                    <div x-show="open" x-cloak x-transition
                         class="absolute right-0 top-full z-30 mt-2 w-52 overflow-hidden rounded-xl border border-border bg-surface py-1 shadow-pop">
                        <div class="border-b border-border px-4 py-3">
                            <p class="text-sm font-semibold">{{ $me['name'] ?? '' }}</p>
                            <p class="text-xs text-fg-muted">{{ $roleLabel }}</p>
                        </div>
                        <a href="/settings" class="flex items-center gap-2.5 px-4 py-2.5 text-sm transition-colors hover:bg-bg">
                            <i data-lucide="settings" class="h-4 w-4 text-fg-muted"></i> Settings
                        </a>
                        <form method="POST" action="/logout">
                            @csrf
                            <button class="flex w-full items-center gap-2.5 px-4 py-2.5 text-sm text-danger transition-colors hover:bg-danger-soft">
                                <i data-lucide="log-out" class="h-4 w-4"></i> Sign out
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        </header>

        <main class="flex-1 p-6">
            @yield('content')
        </main>
    </div>
</div>

{{-- Toasts: flash messages + window.toast() --}}
<div x-data="{ items: [], push(m, t) { const id = Date.now() + Math.random(); this.items.push({ id, m, t }); setTimeout(() => this.items = this.items.filter(i => i.id !== id), 3500); } }"
     x-init="@if (session('success')) push(@js(session('success')), 'success'); @endif @if (session('error')) push(@js(session('error')), 'error'); @endif @if ($errors->any()) push(@js($errors->first()), 'error'); @endif"
     @toast.window="push($event.detail.message, $event.detail.type)"
     class="fixed bottom-5 right-5 z-50 flex flex-col gap-2">
    <template x-for="i in items" :key="i.id">
        <div x-transition class="rounded-xl px-4 py-3 text-sm font-medium shadow-pop"
             :class="i.t === 'error' ? 'bg-danger text-white' : 'bg-fg text-bg'" x-text="i.m"></div>
    </template>
</div>
@stack('scripts')
</body>
</html>
