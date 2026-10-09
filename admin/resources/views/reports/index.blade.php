@extends('layouts.app')

@php
    use App\Support\Format;

    $summary = $data['summary'];
    $revenueByOutlet = $data['revenueByOutlet'];
    $topItems = $data['topItems'];
    $categoryMix = $data['categoryMix'];
    $orderTypes = $data['orderTypes'];
    $paymentMix = $data['paymentMix'];

    $PIE_COLORS = ['#e2470f', '#f5761e', '#0b5e46', '#3b82f6', '#9a6cf1', '#16a34a', '#ef4444'];
    $maxQty = max(1, ...array_map(fn ($t) => $t['qty'], $topItems ?: [['qty' => 1]]));
    $catTotal = array_sum(array_map(fn ($c) => $c['revenue'], $categoryMix));
@endphp

@section('content')
<x-biz.helpers />
<div class="space-y-5">
    <div class="flex items-center justify-end">
        <button type="button" onclick="reportsDownloadTopItems()"
                class="inline-flex items-center gap-2 rounded-lg border border-border bg-surface px-4 py-2 text-sm font-medium transition-colors hover:border-accent hover:text-accent">
            <i data-lucide="download" class="h-4 w-4"></i>
            Export top items (CSV)
        </button>
    </div>

    {{-- Summary --}}
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <x-biz.stat label="Revenue" icon="dollar-sign" :value="Format::formatCurrency($summary['revenue'])" />
        <x-biz.stat label="Orders" icon="shopping-bag" :value="$summary['orders']" />
        <x-biz.stat label="Items Sold" icon="boxes" :value="$summary['itemsSold']" />
        <x-biz.stat label="Avg Order" icon="receipt" :value="Format::formatCurrency($summary['avgOrder'])" />
    </div>

    <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
        {{-- Revenue by outlet --}}
        <section class="card p-5 lg:col-span-7">
            <h2 class="font-display text-lg font-semibold">Revenue by Outlet</h2>
            <div class="mt-4 h-[260px]">
                <canvas id="revenue-by-outlet"></canvas>
            </div>
        </section>

        {{-- Category mix --}}
        <section class="card p-5 lg:col-span-5">
            <h2 class="font-display text-lg font-semibold">Category Mix</h2>
            <div class="mt-4 h-[220px]">
                <canvas id="category-mix"></canvas>
            </div>
            <ul class="mt-4 space-y-2 text-sm">
                @foreach ($categoryMix as $i => $c)
                    <li class="flex items-center justify-between">
                        <span class="inline-flex items-center gap-2">
                            <span class="h-2.5 w-2.5 rounded-full" style="background: {{ $PIE_COLORS[$i % count($PIE_COLORS)] }}"></span>
                            {{ $c['category'] }}
                        </span>
                        <span class="text-fg-muted">
                            {{ Format::formatCurrency($c['revenue']) }} · {{ $catTotal ? Format::round($c['revenue'] / $catTotal * 100) : 0 }}%
                        </span>
                    </li>
                @endforeach
            </ul>
        </section>
    </div>

    <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
        {{-- Top items --}}
        <section class="card p-5 lg:col-span-7">
            <h2 class="font-display text-lg font-semibold">Top Selling Items</h2>
            <ul class="mt-4 space-y-3">
                @foreach ($topItems as $t)
                    <li>
                        <div class="flex items-center justify-between text-sm">
                            <span class="font-medium">{{ $t['name'] }}</span>
                            <span class="text-fg-muted">{{ $t['qty'] }} sold · {{ Format::formatCurrency($t['revenue']) }}</span>
                        </div>
                        <div class="mt-1.5 h-2 w-full rounded-full bg-bg">
                            <div class="h-2 rounded-full bg-accent" style="width: {{ $t['qty'] / $maxQty * 100 }}%"></div>
                        </div>
                    </li>
                @endforeach
            </ul>
        </section>

        {{-- Order types + payment --}}
        <section class="card space-y-5 p-5 lg:col-span-5">
            <div>
                <h2 class="font-display text-lg font-semibold">Order Types</h2>
                <ul class="mt-3 space-y-2 text-sm">
                    @foreach ($orderTypes as $t)
                        <li class="flex items-center justify-between">
                            <span>{{ $t['type'] }}</span>
                            <span class="font-medium">{{ $t['count'] }}</span>
                        </li>
                    @endforeach
                </ul>
            </div>
            <div class="border-t border-border pt-4">
                <h2 class="font-display text-lg font-semibold">Payment Methods</h2>
                <ul class="mt-3 space-y-2 text-sm">
                    @foreach ($paymentMix as $p)
                        <li class="flex items-center justify-between">
                            <span>{{ $p['method'] }}</span>
                            <span class="font-medium">{{ $p['count'] }}</span>
                        </li>
                    @endforeach
                </ul>
            </div>
        </section>
    </div>
</div>
@endsection

@push('scripts')
<script>
    (() => {
        const revenueByOutlet = @js($revenueByOutlet);
        const categoryMix = @js($categoryMix);
        const topItems = @js($topItems);
        const PIE_COLORS = @js($PIE_COLORS);
        const usd = (v) => `$${Number(v).toLocaleString()}`;

        window.reportsDownloadTopItems = () => {
            if (!topItems.length) return;
            bizCsv('top-items.csv', [['Item', 'Quantity', 'Revenue'], ...topItems.map((t) => [t.name, t.qty, t.revenue])]);
        };

        const tooltip = () => ({
            backgroundColor: themeColor('surface'),
            titleColor: themeColor('fg'),
            bodyColor: themeColor('fg'),
            borderColor: themeColor('border'),
            borderWidth: 1,
            cornerRadius: 12,
            padding: 10,
            titleFont: { size: 12 },
            bodyFont: { size: 12 },
        });

        let charts = [];
        const draw = () => {
            charts.forEach((c) => c.destroy());
            const muted = themeColor('fg-muted');
            const border = themeColor('border');
            const accent = themeColor('accent');
            const axis = bizNiceAxis(Math.max(0, ...revenueByOutlet.map((d) => d.revenue)));
            // recharts draws the pie counter-clockwise from 3 o'clock; Chart.js goes clockwise,
            // so feed the slices reversed, starting at 3 o'clock, to get the same picture.
            const pie = categoryMix.map((d, i) => ({ ...d, color: PIE_COLORS[i % PIE_COLORS.length] })).reverse();

            // RevenueBarChart.tsx
            charts = [
                new Chart(document.getElementById('revenue-by-outlet'), {
                    type: 'bar',
                    data: {
                        labels: revenueByOutlet.map((d) => d.outlet),
                        datasets: [{ data: revenueByOutlet.map((d) => d.revenue), barPercentage: 1, categoryPercentage: 0.8, backgroundColor: accent, borderRadius: { topLeft: 6, topRight: 6 }, borderSkipped: 'bottom', hoverBackgroundColor: accent }],
                    },
                    options: {
                        maintainAspectRatio: false,
                        animation: false,
                        plugins: {
                            legend: { display: false },
                            tooltip: { ...tooltip(), displayColors: false, callbacks: { label: (c) => `Revenue : ${usd(c.parsed.y)}` } },
                        },
                        scales: {
                            x: {
                                grid: { display: false }, border: { display: false },
                                ticks: { color: muted, font: { size: 11 }, autoSkip: false, maxRotation: 0, callback(v) { return String(this.getLabelForValue(v)).replace('Outlet ', 'O'); } },
                            },
                            y: {
                                min: 0, max: axis.max,
                                grid: { color: border }, border: { display: false },
                                ticks: { color: muted, font: { size: 11 }, stepSize: axis.step, callback: (v) => `$${v}` },
                            },
                        },
                    },
                }),
                // CategoryPie.tsx
                new Chart(document.getElementById('category-mix'), {
                    type: 'doughnut',
                    data: {
                        labels: pie.map((d) => d.category),
                        datasets: [{ data: pie.map((d) => d.revenue), backgroundColor: pie.map((d) => d.color), borderWidth: 0, spacing: 2 }],
                    },
                    options: {
                        maintainAspectRatio: false,
                        animation: false,
                        rotation: 90,
                        radius: 90,
                        cutout: 55,
                        plugins: {
                            legend: { display: false },
                            tooltip: { ...tooltip(), callbacks: { label: (c) => `${c.label} : ${usd(c.parsed)}` } },
                        },
                    },
                }),
            ];
        };

        document.addEventListener('DOMContentLoaded', draw);
        window.addEventListener('theme-changed', draw);
    })();
</script>
@endpush
