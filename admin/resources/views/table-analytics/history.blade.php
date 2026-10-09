@extends('layouts.app')

@php
    use App\Support\Format;

    $money = fn ($v) => Format::formatCurrency($v);
    $t = $data['table'];
    $sessions = $data['sessions'];
    $totals = ['revenue' => 0, 'guests' => 0, 'mins' => 0];
    foreach ($sessions as $s) {
        $totals['revenue'] += $s['total'];
        $totals['guests'] += $s['customerCount'];
        $totals['mins'] += $s['durationMinutes'];
    }
    $periods = [[1, 'Today'], [7, 'Last 7 Days'], [30, 'Last 30 Days']];
@endphp

@section('content')
@if (! $t)
    <p class="text-sm text-fg-muted">Table not found.</p>
@else
<div class="space-y-5" x-data="tableHistory(@js($t['number']), @js($sessions))">
    <div class="flex flex-wrap items-center justify-between gap-3">
        <a href="/table-analytics" class="inline-flex items-center gap-2 text-sm font-medium text-fg-muted hover:text-accent">
            <i data-lucide="arrow-left" class="h-4 w-4"></i> Analytics
        </a>
        <button type="button" @click="exportCsv()" class="inline-flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm font-semibold transition-colors hover:bg-bg">
            <i data-lucide="download" class="h-4 w-4"></i> Export CSV
        </button>
    </div>

    <div class="card p-5">
        <h2 class="font-display text-xl font-semibold">Table {{ $t['number'] }}@if (! empty($t['name']))<span class="text-sm text-fg-muted"> · {{ $t['name'] }}</span>@endif</h2>
        <div class="mt-3 flex flex-wrap gap-x-8 gap-y-2 text-sm text-fg-muted">
            <span>{{ count($sessions) }} sessions</span>
            <span>{{ $totals['guests'] }} guests</span>
            <span>{{ $money($totals['revenue']) }} revenue</span>
            <span>{{ Format::js($totals['mins']) }} min total occupied</span>
        </div>
        <div class="mt-4 flex flex-wrap gap-2">
            @foreach ($periods as [$d, $label])
                <a href="/table-history/{{ $t['id'] }}?days={{ $d }}"
                   class="rounded-pill px-3.5 py-1.5 text-sm font-medium transition-colors {{ $days === $d ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40' }}">{{ $label }}</a>
            @endforeach
        </div>
    </div>

    {{-- Timeline --}}
    @if (count($sessions) === 0)
        <div class="card px-5 py-16 text-center text-sm text-fg-muted">No sessions in this period.</div>
    @else
        <ol class="relative space-y-4 border-l border-border pl-6">
            @foreach ($sessions as $s)
                <li class="relative">
                    <span class="absolute -left-[1.69rem] top-1.5 h-3 w-3 rounded-full ring-4 ring-surface {{ $s['status'] === 'OPEN' ? 'bg-danger' : 'bg-accent' }}"></span>
                    <div class="card p-4">
                        <div class="flex flex-wrap items-center justify-between gap-2">
                            <p class="font-medium" x-data="{ o: @js($s['openedAt']), c: @js($s['closedAt'] ?? null) }"
                               x-text="fmtDate(o, 'EEE, MMM d · h:mm a') + (c ? ' – ' + fmtDate(c, 'h:mm a') : ' (open)')"></p>
                            <span class="font-display text-lg font-semibold">{{ $money($s['total']) }}</span>
                        </div>
                        <div class="mt-2 flex flex-wrap gap-x-5 gap-y-1 text-xs text-fg-muted">
                            <span class="inline-flex items-center gap-1.5"><i data-lucide="users" class="h-3.5 w-3.5"></i> {{ $s['customerCount'] }} guests</span>
                            <span class="inline-flex items-center gap-1.5"><i data-lucide="clock" class="h-3.5 w-3.5"></i> {{ Format::js($s['durationMinutes']) }} min</span>
                            @if (! empty($s['waiterName']))
                                <span class="inline-flex items-center gap-1.5"><i data-lucide="user-round" class="h-3.5 w-3.5"></i> {{ $s['waiterName'] }}</span>
                            @endif
                            @if (! empty($s['paymentMethod']))
                                <span>Paid · {{ $s['paymentMethod'] }}</span>
                            @endif
                        </div>
                        @if (count($s['items']) > 0)
                            <ul class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-sm text-fg-muted">
                                @foreach ($s['items'] as $it)
                                    <li><span class="font-medium text-fg">{{ $it['qty'] }}×</span> {{ $it['name'] }}</li>
                                @endforeach
                            </ul>
                        @endif
                        @if ($s['discount'] > 0 || $s['tax'] > 0 || $s['serviceCharge'] > 0 || $s['tip'] > 0)
                            <p class="mt-2 text-xs text-fg-muted">
                                Subtotal {{ $money($s['subtotal']) }}{{ $s['discount'] > 0 ? ' · −'.$money($s['discount']).' disc' : '' }}{{ $s['tax'] > 0 ? ' · +'.$money($s['tax']).' tax' : '' }}{{ $s['serviceCharge'] > 0 ? ' · +'.$money($s['serviceCharge']).' svc' : '' }}{{ $s['tip'] > 0 ? ' · +'.$money($s['tip']).' tip' : '' }}
                            </p>
                        @endif
                    </div>
                </li>
            @endforeach
        </ol>
    @endif
</div>
@endif
@endsection

@push('scripts')
<script>
    document.addEventListener('alpine:init', () => {
        // TableHistoryView.tsx — CSV export
        Alpine.data('tableHistory', (number, sessions) => ({
            exportCsv() {
                const header = ['Date', 'Opened', 'Closed', 'Duration(min)', 'Guests', 'Waiter', 'Items', 'Subtotal', 'Discount', 'Tax', 'Service', 'Tip', 'Total', 'Payment', 'Status'];
                const rows = sessions.map((s) => [
                    s.openedAt.slice(0, 10),
                    new Date(s.openedAt).toLocaleTimeString(),
                    s.closedAt ? new Date(s.closedAt).toLocaleTimeString() : '',
                    s.durationMinutes,
                    s.customerCount,
                    s.waiterName ?? '',
                    s.items.map((i) => `${i.qty}x ${i.name}`).join('; '),
                    s.subtotal, s.discount, s.tax, s.serviceCharge, s.tip, s.total,
                    s.paymentMethod ?? '',
                    s.status,
                ]);
                downloadFile(`table-${number}-history.csv`, 'text/csv;charset=utf-8', toCsv([header, ...rows]));
            },
        }));
    });
</script>
@endpush
