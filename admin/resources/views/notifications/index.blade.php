@extends('layouts.app')

@php
    use App\Support\Format;
    use Carbon\Carbon;

    $META = [
        'order' => ['shopping-bag', 'bg-info-soft text-info'],
        'reservation' => ['calendar-clock', 'bg-accent-soft text-accent'],
        'stock' => ['package-x', 'bg-danger-soft text-danger'],
        'table' => ['layout-dashboard', 'bg-warn-soft text-warn'],
    ];
@endphp

@section('content')
<div class="mx-auto max-w-2xl">
    <div class="card divide-y divide-border">
        @if (count($notifications) === 0)
            <p class="px-5 py-12 text-center text-sm text-fg-muted">You&rsquo;re all caught up.</p>
        @endif
        @foreach ($notifications as $n)
            @php [$icon, $cls] = $META[$n['type']] ?? $META['order']; @endphp
            <div class="flex items-start gap-3 px-5 py-4">
                <span class="grid h-9 w-9 shrink-0 place-items-center rounded-lg {{ $cls }}">
                    <i data-lucide="{{ $icon }}" class="h-[18px] w-[18px]"></i>
                </span>
                <div class="min-w-0 flex-1">
                    <p class="text-sm font-medium">{{ $n['title'] }}</p>
                    <p class="text-xs text-fg-muted">{{ $n['detail'] }}</p>
                </div>
                <span class="shrink-0 text-xs text-fg-muted">{{ Format::local(Carbon::parse($n['time']))->format('M j, g:i A') }}</span>
            </div>
        @endforeach
    </div>
</div>
@endsection
