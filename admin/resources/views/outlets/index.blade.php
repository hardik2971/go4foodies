@extends('layouts.app')

@php
    use App\Support\Format;

    // outlets-data.ts current() / margin()
    $current = fn (array $o) => $o['weekly'] ? $o['weekly'][count($o['weekly']) - 1] : ['week' => '', 'revenue' => 0, 'cost' => 0];
    $margin = function (array $o) use ($current) {
        $c = $current($o);

        return $c['revenue'] == 0 ? 0 : Format::round(($c['revenue'] - $c['cost']) / $c['revenue'] * 100);
    };

    $activeCount = count(array_filter($outlets, fn ($o) => $o['isActive']));
    $revenue = array_sum(array_map(fn ($o) => $current($o)['revenue'], $outlets));
    $cost = array_sum(array_map(fn ($o) => $current($o)['cost'], $outlets));
    $avgMargin = $revenue ? Format::round(($revenue - $cost) / $revenue * 100) : 0;

    $withMargin = array_map(fn ($o) => $o + ['margin' => $margin($o)], $outlets);
@endphp

@section('content')
<x-biz.helpers />
<div x-data="outletsManager(@js($withMargin))" class="space-y-5">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <x-biz.stat label="Total Outlets" icon="store" :value="count($outlets)" />
        <x-biz.stat label="Active" icon="circle-check" :value="$activeCount" />
        <x-biz.stat label="Weekly Revenue" icon="dollar-sign" :value="Format::formatCurrency($revenue)" />
        <x-biz.stat label="Avg Margin" icon="percent" :value="$avgMargin.'%'" />
    </div>

    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
        @foreach ($withMargin as $i => $o)
            @php $c = $current($o); @endphp
            <button type="button" @click="open({{ $i }})" class="card p-5 text-left transition-shadow hover:shadow-pop">
                <div class="flex items-start justify-between">
                    <div>
                        <h3 class="font-display text-lg font-semibold">{{ $o['name'] }}</h3>
                        <p class="mt-0.5 inline-flex items-center gap-1 text-xs text-fg-muted">
                            <i data-lucide="map-pin" class="h-3.5 w-3.5"></i> {{ $o['location'] }}
                        </p>
                    </div>
                    <span class="rounded-md px-2 py-0.5 text-xs font-semibold {{ $o['isActive'] ? 'bg-success-soft text-success' : 'bg-bg text-fg-muted' }}">
                        {{ $o['isActive'] ? 'Active' : 'Closed' }}
                    </span>
                </div>

                <div class="mt-4 grid grid-cols-2 gap-3">
                    <div class="rounded-lg bg-bg px-3 py-2">
                        <p class="text-xs text-fg-muted">Revenue</p>
                        <p class="font-display text-base font-semibold">{{ Format::formatCurrency($c['revenue']) }}</p>
                    </div>
                    <div class="rounded-lg bg-bg px-3 py-2">
                        <p class="text-xs text-fg-muted">Op. Cost</p>
                        <p class="font-display text-base font-semibold">{{ Format::formatCurrency($c['cost']) }}</p>
                    </div>
                </div>

                <div class="mt-3 flex items-center justify-between">
                    <span class="inline-flex items-center gap-1.5 text-xs text-fg-muted">
                        <i data-lucide="user" class="h-3.5 w-3.5"></i> {{ $o['manager'] }}
                    </span>
                    <span class="rounded-full px-1.5 py-0.5 text-xs font-semibold {{ $o['margin'] >= 0 ? 'bg-success-soft text-success' : 'bg-danger-soft text-danger' }}">
                        {{ $o['margin'] >= 0 ? '+' : '' }}{{ $o['margin'] }}% margin
                    </span>
                </div>
            </button>
        @endforeach
    </div>

    <x-biz.modal show="!!active" close="close()" title-expr="active ? active.name : ''">
        <div class="space-y-5" x-show="active">
            <div class="flex items-center justify-between">
                <span class="inline-flex items-center gap-1.5 text-sm text-fg-muted">
                    <i data-lucide="map-pin" class="h-4 w-4"></i> <span x-text="active?.location"></span>
                </span>
                <span class="rounded-full px-1.5 py-0.5 text-xs font-semibold"
                      :class="(active?.margin ?? 0) >= 0 ? 'bg-success-soft text-success' : 'bg-danger-soft text-danger'"
                      x-text="`${(active?.margin ?? 0) >= 0 ? '+' : ''}${active?.margin ?? 0}% margin`"></span>
            </div>

            <dl class="divide-y divide-border rounded-xl border border-border px-4">
                <div class="flex items-center justify-between py-2.5 text-sm">
                    <dt class="inline-flex items-center gap-2 text-fg-muted"><i data-lucide="map-pin" class="h-4 w-4"></i> Address</dt>
                    <dd class="text-right font-medium" x-text="active?.address"></dd>
                </div>
                <div class="flex items-center justify-between py-2.5 text-sm">
                    <dt class="inline-flex items-center gap-2 text-fg-muted"><i data-lucide="phone" class="h-4 w-4"></i> Phone</dt>
                    <dd class="text-right font-medium" x-text="active?.phone"></dd>
                </div>
                <div class="flex items-center justify-between py-2.5 text-sm">
                    <dt class="inline-flex items-center gap-2 text-fg-muted"><i data-lucide="user" class="h-4 w-4"></i> Manager</dt>
                    <dd class="text-right font-medium" x-text="active?.manager"></dd>
                </div>
            </dl>

            <div>
                <div class="mb-2 flex items-center justify-between">
                    <p class="text-sm font-medium">Revenue vs Operational Cost</p>
                    <div class="flex items-center gap-3 text-xs text-fg-muted">
                        <span class="inline-flex items-center gap-1.5"><span class="h-2.5 w-2.5 rounded-full bg-[#3a3a3a]"></span> Revenue</span>
                        <span class="inline-flex items-center gap-1.5"><span class="h-2.5 w-2.5 rounded-full bg-accent"></span> Cost</span>
                    </div>
                </div>
                <div class="h-[180px]"><canvas id="outlet-weekly"></canvas></div>
            </div>
        </div>
    </x-biz.modal>
</div>
@endsection

@push('scripts')
<script>
    function outletsManager(outlets) {
        let chart = null;
        return {
            outlets,
            active: null,
            open(i) {
                this.active = this.outlets[i];
                this.$nextTick(() => this.draw());
            },
            close() {
                this.active = null;
                if (chart) { chart.destroy(); chart = null; }
            },
            init() {
                window.addEventListener('theme-changed', () => this.active && this.draw());
            },
            // OutletWeeklyChart.tsx
            draw() {
                if (chart) chart.destroy();
                const data = this.active.weekly;
                const muted = themeColor('fg-muted');
                const axis = bizNiceAxis(Math.max(0, ...data.flatMap((d) => [d.revenue, d.cost])));
                chart = new Chart(document.getElementById('outlet-weekly'), {
                    type: 'line',
                    data: {
                        labels: data.map((d) => d.week),
                        datasets: [
                            { label: 'Revenue', data: data.map((d) => d.revenue), borderColor: '#3a3a3a', borderWidth: 2.5, pointRadius: 0, tension: 0.4, cubicInterpolationMode: 'monotone' },
                            { label: 'Cost', data: data.map((d) => d.cost), borderColor: themeColor('accent'), borderWidth: 2.5, pointRadius: 0, tension: 0.4, cubicInterpolationMode: 'monotone' },
                        ],
                    },
                    options: {
                        maintainAspectRatio: false,
                        animation: false,
                        interaction: { mode: 'index', intersect: false },
                        plugins: {
                            legend: { display: false },
                            tooltip: {
                                backgroundColor: themeColor('surface'), titleColor: themeColor('fg'), bodyColor: themeColor('fg'),
                                borderColor: themeColor('border'), borderWidth: 1, cornerRadius: 12, padding: 10,
                                callbacks: { label: (c) => `${c.dataset.label} : $${Number(c.parsed.y).toLocaleString()}` },
                            },
                        },
                        scales: {
                            x: { grid: { display: false }, border: { display: false }, ticks: { color: muted, font: { size: 11 } } },
                            y: { min: 0, max: axis.max, grid: { color: themeColor('border') }, border: { display: false }, ticks: { color: muted, font: { size: 11 }, stepSize: axis.step, callback: (v) => `$${v / 1000}K` } },
                        },
                    },
                });
            },
        };
    }
</script>
@endpush
