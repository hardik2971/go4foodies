@extends('layouts.app')

@php
    use App\Support\Format;

    $money = fn ($v) => Format::formatCurrency($v);
    $live = [
        ['Total', $data['live']['total'], 'text-fg'],
        ['Available', $data['live']['available'], 'text-success'],
        ['Occupied', $data['live']['occupied'], 'text-danger'],
        ['Reserved', $data['live']['reserved'], 'text-warn'],
        ['Cleaning', $data['live']['cleaning'], 'text-info'],
        ['Out of Service', $data['live']['outOfService'], 'text-fg-muted'],
    ];
    $s = $data['summary'];
    $summary = [
        ['Table Sessions', Format::js($s['sessions'])],
        ['Customers', Format::js($s['customers'])],
        ['Orders', Format::js($s['orders'])],
        ['Revenue', $money($s['revenue'])],
        ['Avg Bill', $money($s['avgBill'])],
        ['Avg Guests/Table', Format::js($s['avgCustomersPerTable'])],
        ['Avg Dining', Format::js($s['avgDiningMinutes']).' min'],
    ];
    $periods = [[1, 'Today'], [7, 'Last 7 Days'], [30, 'Last 30 Days']];
    $topLabels = ['highestRevenue' => 'Highest Revenue', 'mostUsed' => 'Most Used', 'mostCustomers' => 'Most Customers', 'highestAvgBill' => 'Highest Avg Bill', 'longestOccupied' => 'Longest Occupied', 'fastestTurnover' => 'Fastest Turnover'];
    $leastLabels = ['leastUsed' => 'Least Used', 'lowestRevenue' => 'Lowest Revenue', 'lowestOccupancy' => 'Lowest Occupancy'];
    $exportBtn = 'rounded-lg border border-border px-3 py-2 text-sm font-semibold transition-colors hover:bg-bg';
@endphp

@section('content')
<div class="space-y-5" x-data="tableAnalytics(@js($data))">
    {{-- Period tabs + export --}}
    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            @foreach ($periods as [$d, $label])
                <a href="/table-analytics?days={{ $d }}"
                   class="rounded-pill px-4 py-1.5 text-sm font-medium transition-colors {{ $data['days'] === $d ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40' }}">{{ $label }}</a>
            @endforeach
        </div>
        <div class="flex items-center gap-2">
            <span class="text-xs text-fg-muted">Export</span>
            <button type="button" @click="exportCsv()" class="inline-flex items-center gap-1.5 {{ $exportBtn }}"><i data-lucide="download" class="h-4 w-4"></i> CSV</button>
            <button type="button" @click="exportXls()" class="{{ $exportBtn }}">Excel</button>
            <button type="button" @click="printPdf()" class="{{ $exportBtn }}">PDF</button>
        </div>
    </div>

    {{-- Live stats --}}
    <div class="card flex flex-wrap items-center gap-x-8 gap-y-3 p-4">
        @foreach ($live as [$label, $value, $tone])
            <div>
                <p class="font-display text-2xl font-semibold {{ $tone }}">{{ $value }}</p>
                <p class="text-xs text-fg-muted">{{ $label }}</p>
            </div>
        @endforeach
    </div>

    {{-- Summary --}}
    <div class="grid grid-cols-2 gap-4 md:grid-cols-4 xl:grid-cols-7">
        @foreach ($summary as [$label, $value])
            <div class="card p-4">
                <p class="text-xs text-fg-muted">{{ $label }}</p>
                <p class="mt-1 font-display text-xl font-semibold">{{ $value }}</p>
            </div>
        @endforeach
    </div>

    <div class="grid gap-5 lg:grid-cols-12">
        {{-- Busy hours --}}
        <div class="card p-5 lg:col-span-8">
            <div class="flex items-center justify-between">
                <h2 class="font-display text-lg font-semibold">Busy Hours</h2>
                <div class="flex gap-4 text-sm">
                    <span class="inline-flex items-center gap-1.5 text-fg-muted"><i data-lucide="clock" class="h-4 w-4"></i> Peak {{ $data['peakHour'] }}</span>
                    <span class="inline-flex items-center gap-1.5 text-fg-muted"><i data-lucide="calendar-days" class="h-4 w-4"></i> {{ $data['peakDay'] }}</span>
                </div>
            </div>
            <div class="mt-4 h-64"><canvas x-ref="busy"></canvas></div>
        </div>

        {{-- Top / least performers --}}
        <div class="space-y-5 lg:col-span-4">
            <div class="card p-5">
                <h2 class="flex items-center gap-2 font-display text-lg font-semibold"><i data-lucide="trophy" class="h-4 w-4 text-gold"></i> Top Tables</h2>
                <ul class="mt-3 space-y-2 text-sm">
                    @foreach ($topLabels as $key => $label)
                        @php $v = $data['top'][$key] ?? null; @endphp
                        <li class="flex items-center justify-between gap-3">
                            <span class="text-fg-muted">{{ $label }}</span>
                            <span class="font-medium">{{ $v ? "Table {$v['number']} · {$v['value']}" : '—' }}</span>
                        </li>
                    @endforeach
                </ul>
            </div>
            <div class="card p-5">
                <h2 class="flex items-center gap-2 font-display text-lg font-semibold"><i data-lucide="trending-down" class="h-4 w-4 text-fg-muted"></i> Needs Attention</h2>
                <ul class="mt-3 space-y-2 text-sm">
                    @foreach ($leastLabels as $key => $label)
                        @php $v = $data['least'][$key] ?? null; @endphp
                        <li class="flex items-center justify-between gap-3">
                            <span class="text-fg-muted">{{ $label }}</span>
                            <span class="font-medium">{{ $v ? "Table {$v['number']} · {$v['value']}" : '—' }}</span>
                        </li>
                    @endforeach
                </ul>
            </div>
        </div>
    </div>

    {{-- Customer analytics --}}
    <div class="grid gap-5 lg:grid-cols-3">
        <div class="card p-5">
            <h2 class="font-display text-lg font-semibold">Customers</h2>
            <div class="mt-3 grid grid-cols-2 gap-3 text-center">
                <div class="rounded-lg bg-bg px-3 py-3">
                    <p class="text-xs text-fg-muted">Served</p>
                    <p class="mt-0.5 font-display text-xl font-semibold">{{ $data['customer']['served'] }}</p>
                </div>
                <div class="rounded-lg bg-bg px-3 py-3">
                    <p class="text-xs text-fg-muted">Avg Spend</p>
                    <p class="mt-0.5 font-display text-xl font-semibold">{{ $money($data['customer']['avgSpend']) }}</p>
                </div>
            </div>
        </div>
        <div class="card p-5">
            <h2 class="flex items-center gap-2 font-display text-lg font-semibold"><i data-lucide="star" class="h-4 w-4 text-gold"></i> Favourite Items</h2>
            <ul class="mt-3 space-y-1.5 text-sm">
                @forelse ($data['customer']['favouriteItems'] as $f)
                    <li class="flex justify-between"><span class="truncate">{{ $f['name'] }}</span><span class="text-fg-muted">{{ $f['qty'] }}</span></li>
                @empty
                    <li class="text-fg-muted">No data yet.</li>
                @endforelse
            </ul>
        </div>
        <div class="card p-5">
            <h2 class="flex items-center gap-2 font-display text-lg font-semibold"><i data-lucide="wallet" class="h-4 w-4 text-accent"></i> Payment Methods</h2>
            <ul class="mt-3 space-y-1.5 text-sm">
                @forelse ($data['customer']['paymentMix'] as $p)
                    <li class="flex justify-between"><span>{{ $p['method'] }}</span><span class="text-fg-muted">{{ $p['count'] }}</span></li>
                @empty
                    <li class="text-fg-muted">No payments yet.</li>
                @endforelse
            </ul>
        </div>
    </div>

    {{-- Per-table performance --}}
    <div class="card overflow-x-auto">
        <table class="w-full text-sm">
            <thead>
                <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
                    @foreach (['Table', 'Sessions', 'Customers', 'Orders', 'Revenue', 'Avg Bill', 'Avg Dining', 'Occupancy', 'Utilization'] as $h)
                        <th class="px-5 py-3 font-medium">{{ $h }}</th>
                    @endforeach
                </tr>
            </thead>
            <tbody>
                @forelse ($data['perTable'] as $t)
                    <tr class="border-b border-border last:border-0 hover:bg-bg/60">
                        <td class="px-5 py-3 font-medium">
                            <a href="/table-history/{{ $t['id'] }}" class="hover:text-accent hover:underline">
                                Table {{ $t['number'] }}@if (! empty($t['name']))<span class="text-xs text-fg-muted"> · {{ $t['name'] }}</span>@endif
                            </a>
                        </td>
                        <td class="px-5 py-3 text-fg-muted">{{ $t['sessions'] }}</td>
                        <td class="px-5 py-3 text-fg-muted">{{ $t['customers'] }}</td>
                        <td class="px-5 py-3 text-fg-muted">{{ $t['orders'] }}</td>
                        <td class="px-5 py-3 font-medium">{{ $money($t['revenue']) }}</td>
                        <td class="px-5 py-3 text-fg-muted">{{ $money($t['avgBill']) }}</td>
                        <td class="px-5 py-3 text-fg-muted">{{ Format::js($t['avgDiningMinutes']) }} min</td>
                        <td class="px-5 py-3">
                            <span class="inline-flex items-center gap-2">
                                <span class="h-1.5 w-16 overflow-hidden rounded-full bg-border">
                                    <span class="block h-full rounded-full bg-accent" style="width: {{ Format::js($t['occupancyPct']) }}%"></span>
                                </span>
                                {{ Format::js($t['occupancyPct']) }}%
                            </span>
                        </td>
                        <td class="px-5 py-3 text-fg-muted">{{ Format::js($t['utilizationPct']) }}%</td>
                    </tr>
                @empty
                    <tr><td colspan="9" class="px-5 py-12 text-center text-sm text-fg-muted">No tables yet.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>
@endsection

@push('scripts')
<script>
    document.addEventListener('alpine:init', () => {
        const HEADER = ['Table', 'Name', 'Sessions', 'Customers', 'Orders', 'Revenue', 'AvgBill', 'AvgDiningMin', 'OccupancyPct', 'UtilizationPct'];
        const toRow = (t) => [t.number, t.name ?? '', t.sessions, t.customers, t.orders, t.revenue, t.avgBill, t.avgDiningMinutes, t.occupancyPct, t.utilizationPct];

        // TableAnalyticsView.tsx
        Alpine.data('tableAnalytics', (data) => ({
            chart: null,
            init() {
                this.draw();
                window.addEventListener('theme-changed', () => this.draw());
            },
            draw() {
                this.chart?.destroy();
                const muted = themeColor('fg-muted');
                const family = getComputedStyle(document.body).fontFamily;
                // recharts' default 5 integer ticks (allowDecimals=false): 0..4*step
                const peak = Math.max(0, ...data.busyHours.map((b) => b.sessions));
                const step = Math.max(1, Math.ceil(peak / 4));
                const yMax = peak > 0 ? step * 4 : 4;
                this.chart = new Chart(this.$refs.busy, {
                    type: 'bar',
                    data: {
                        labels: data.busyHours.map((b) => b.label),
                        datasets: [{ label: 'sessions', data: data.busyHours.map((b) => b.sessions), backgroundColor: themeColor('accent'), borderRadius: { topLeft: 6, topRight: 6 }, borderSkipped: 'bottom' }],
                    },
                    options: {
                        maintainAspectRatio: false,
                        animation: false,
                        layout: { padding: { top: 8, right: 8 } },
                        plugins: {
                            legend: { display: false },
                            tooltip: {
                                backgroundColor: themeColor('surface'), titleColor: themeColor('fg'), bodyColor: themeColor('fg'),
                                borderColor: themeColor('border'), borderWidth: 1, cornerRadius: 12, titleFont: { size: 12 }, bodyFont: { size: 12 },
                            },
                        },
                        scales: {
                            x: { grid: { display: false }, border: { display: false }, ticks: { color: muted, font: { size: 11, family } } },
                            y: { min: 0, max: yMax, border: { display: false, dash: [3, 3] }, grid: { color: themeColor('border') }, ticks: { stepSize: step, precision: 0, color: muted, font: { size: 11, family } } },
                        },
                    },
                });
            },
            exportCsv() {
                downloadFile('table-performance.csv', 'text/csv;charset=utf-8', toCsv([HEADER, ...data.perTable.map(toRow)]));
            },
            // Excel via an HTML table (.xls) — opens natively in Excel, no library needed.
            exportXls() {
                const head = `<tr>${HEADER.map((h) => `<th>${h}</th>`).join('')}</tr>`;
                const body = data.perTable.map((t) => `<tr>${toRow(t).map((c) => `<td>${c}</td>`).join('')}</tr>`).join('');
                const html = `<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel"><head><meta charset="utf-8"></head><body><table border="1"><thead>${head}</thead><tbody>${body}</tbody></table></body></html>`;
                downloadFile('table-performance.xls', 'application/vnd.ms-excel', html);
            },
            printPdf() {
                const w = window.open('', '_blank', 'width=900,height=700');
                if (!w) return;
                const head = `<tr>${HEADER.map((h) => `<th>${h}</th>`).join('')}</tr>`;
                const body = data.perTable.map((t) => `<tr>${toRow(t).map((c) => `<td>${c}</td>`).join('')}</tr>`).join('');
                w.document.write(`<!doctype html><html><head><title>Table Performance</title><style>
                    body{font-family:system-ui,sans-serif;padding:24px;color:#0a1c18}
                    h1{font-size:20px;margin:0 0 4px} .muted{color:#666;font-size:12px;margin:0 0 16px}
                    table{width:100%;border-collapse:collapse;font-size:12px} th,td{border:1px solid #ddd;padding:6px 8px;text-align:left}
                    th{background:#f6f6f6}
                </style></head><body>
                    <h1>Go4Foodie — Table Performance</h1>
                    <p class="muted">${data.summary.sessions} sessions · ${data.summary.customers} customers · $${data.summary.revenue.toLocaleString()} revenue</p>
                    <table><thead>${head}</thead><tbody>${body}</tbody></table>
                    <script>window.onload=function(){window.print()}<\/script>
                </body></html>`);
                w.document.close();
            },
        }));
    });
</script>
@endpush
