@extends('layouts.app')

@php
    use App\Support\Format;

    $kpiIcons = ['orders' => 'package', 'delivered' => 'package-check', 'canceled' => 'package-x', 'revenue' => 'coins'];
    $delta = fn ($v) => ($v > 0 ? '+' : '').Format::js($v).'%';
    $money = fn ($v) => Format::formatCurrency($v);
    $pos = $data['pos'];

    // PaymentGauge (pure SVG ticked semicircle)
    $gauge = (function (float $value) {
        $cx = 120; $cy = 118; $rIn = 84; $rOut = 108; $ticks = 48;
        $lerp = function ($t) {
            $a = [22, 163, 74]; $b = [241, 90, 36];
            $c = array_map(fn ($i) => (int) round($a[$i] + ($b[$i] - $a[$i]) * $t), [0, 1, 2]);
            return "rgb({$c[0]}, {$c[1]}, {$c[2]})";
        };
        $lines = [];
        for ($i = 0; $i < $ticks; $i++) {
            $t = $i / ($ticks - 1);
            $rad = deg2rad(180 - $t * 180);
            $lines[] = [
                'x1' => $cx + $rIn * cos($rad), 'y1' => $cy - $rIn * sin($rad),
                'x2' => $cx + $rOut * cos($rad), 'y2' => $cy - $rOut * sin($rad),
                'dim' => $t * 100 > $value + 4, 'color' => $lerp($t),
            ];
        }
        return $lines;
    })((float) $pos['payment']['cash']);
    $barColors = ['bg-accent', 'bg-[#f99a55]', 'bg-[#fdd0aa]'];
@endphp

@section('content')
<div class="flex flex-col gap-5 xl:flex-row">
    {{-- ---- Left + middle column ---- --}}
    <div class="min-w-0 flex-1 space-y-5">
        <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-4">
            @foreach ($data['kpis'] as $kpi)
                @php $accent = ! empty($kpi['accent']); $up = $kpi['delta'] >= 0; @endphp
                <div class="rounded-card border p-5 shadow-card transition-colors {{ $accent ? 'border-accent bg-accent text-white' : 'border-border bg-surface' }}">
                    <div class="flex items-center gap-2.5">
                        <span class="grid h-9 w-9 place-items-center rounded-lg {{ $accent ? 'bg-white/20 text-white' : 'bg-bg text-fg-muted' }}">
                            <i data-lucide="{{ $kpiIcons[$kpi['key']] ?? 'package' }}" class="h-[18px] w-[18px]"></i>
                        </span>
                        <span class="text-sm font-medium {{ $accent ? 'text-white/90' : 'text-fg-muted' }}">{{ $kpi['label'] }}</span>
                    </div>
                    <p class="mt-4 font-display text-[32px] font-semibold leading-none">{{ $kpi['value'] }}</p>
                    <div class="mt-3 flex items-center gap-2">
                        <span class="inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 text-xs font-semibold {{ $accent ? 'bg-white/20 text-white' : ($up ? 'bg-success-soft text-success' : 'bg-danger-soft text-danger') }}">
                            <i data-lucide="{{ $up ? 'trending-up' : 'trending-down' }}" class="h-3 w-3"></i>
                            {{ $delta($kpi['delta']) }}
                        </span>
                        <span class="text-xs {{ $accent ? 'text-white/80' : 'text-fg-muted' }}">Since last month</span>
                    </div>
                </div>
            @endforeach
        </div>

        <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
            {{-- Outlets operational cost vs revenue --}}
            <div class="lg:col-span-7">
                <section class="card p-5">
                    <div class="flex items-start justify-between">
                        <h2 class="font-display text-lg font-semibold">Outlets Operational Cost Vs Revenue</h2>
                        <x-ops.filter-pill label="Weekly" />
                    </div>
                    <div class="mt-4 flex items-end justify-between">
                        <p class="font-display text-4xl font-semibold">
                            {{ $data['revenueTotal'] }}
                            <span class="ml-2 align-middle text-base font-normal text-fg-muted">Revenue</span>
                        </p>
                        <div class="flex items-center gap-4 text-xs text-fg-muted">
                            <span class="inline-flex items-center gap-1.5"><span class="h-2.5 w-2.5 rounded-full bg-[#3a3a3a]"></span> Sells</span>
                            <span class="inline-flex items-center gap-1.5"><span class="h-2.5 w-2.5 rounded-full bg-accent"></span> Operational Cost</span>
                        </div>
                    </div>
                    <div class="relative mt-3 h-[260px]" x-data="costRevenueChart(@js($data['outletSeries']), @js($data['outletActive']))">
                        <canvas x-ref="canvas"></canvas>
                        <div x-ref="tip" class="pointer-events-none absolute flex flex-col gap-1 opacity-0 transition-opacity"></div>
                    </div>
                </section>
            </div>

            <div class="space-y-5 lg:col-span-5">
                {{-- Top categories (+ edit override) --}}
                <section class="card p-5" x-data="topCategoriesEditor(@js($data['topCategories']), @js($categoryOptions))">
                    <div class="flex items-center justify-between">
                        <h2 class="font-display text-lg font-semibold">Top Categories Item</h2>
                        @if ($editable)
                            <button type="button" @click="openEditor()" aria-label="Edit top categories"
                                    class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-accent-soft hover:text-accent">
                                <i data-lucide="pencil" class="h-4 w-4"></i>
                            </button>
                        @endif
                    </div>
                    <div class="mt-4 grid grid-cols-3 gap-3">
                        @foreach ($data['topCategories'] as $c)
                            <div>
                                <div class="relative h-24 w-full overflow-hidden rounded-xl">
                                    @if ($c['image'])<img src="{{ $c['image'] }}" alt="{{ $c['name'] }}" class="absolute inset-0 h-full w-full object-cover">@endif
                                    <div class="absolute inset-0 bg-gradient-to-t from-black/65 to-transparent"></div>
                                    <span class="absolute inset-x-0 bottom-2 text-center text-xs font-semibold text-white">{{ $c['name'] }}</span>
                                </div>
                                <p class="mt-2 text-center font-display text-2xl font-semibold">{{ Format::js($c['percent']) }}%</p>
                            </div>
                        @endforeach
                    </div>

                    @if ($editable)
                        <x-ops.modal show="open" close="open = false" title="Top categories">
                            <div class="space-y-4">
                                <template x-for="(row, i) in rows" :key="i">
                                    <div class="grid grid-cols-[1fr_auto] gap-3">
                                        <select x-model="row.name" class="w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none focus:border-accent">
                                            <option value="">— None —</option>
                                            <template x-for="c in options" :key="c"><option :value="c" x-text="c" :selected="c === row.name"></option></template>
                                        </select>
                                        <div class="flex items-center gap-1">
                                            <input type="number" min="0" max="100" x-model.number="row.percent"
                                                   class="w-20 rounded-lg border border-border bg-surface px-3 py-2.5 text-sm outline-none focus:border-accent">
                                            <span class="text-sm text-fg-muted">%</span>
                                        </div>
                                    </div>
                                </template>
                                <div class="flex items-center justify-between pt-1">
                                    <button type="button" @click="save(true)" :disabled="pending" class="text-sm font-medium text-fg-muted hover:text-accent">Reset to auto</button>
                                    <div class="flex gap-3">
                                        <button type="button" @click="open = false" class="rounded-lg border border-border px-4 py-2 text-sm font-medium hover:bg-bg">Cancel</button>
                                        <button type="button" @click="save(false)" :disabled="pending" class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent-deep disabled:opacity-60" x-text="pending ? 'Saving…' : 'Save'"></button>
                                    </div>
                                </div>
                            </div>
                        </x-ops.modal>
                    @endif
                </section>

                {{-- Employee status --}}
                <section class="card p-5">
                    <div class="flex items-start justify-between">
                        <h2 class="font-display text-lg font-semibold">Employee Status</h2>
                        <button type="button" aria-label="Open employee status" class="grid h-8 w-8 place-items-center rounded-lg border border-border text-fg-muted transition-colors hover:border-accent/40 hover:text-accent">
                            <i data-lucide="arrow-up-right" class="h-4 w-4"></i>
                        </button>
                    </div>
                    <p class="mt-1 text-sm text-fg-muted">Total Employees → <span class="font-semibold text-fg">{{ $data['employee']['total'] }}</span></p>
                    <div class="mt-2 grid grid-cols-[1fr_auto] items-center gap-4">
                        <div class="relative min-w-0" x-data="employeeGauge(@js($data['employee']['segments']))">
                            <div class="h-[150px]"><canvas x-ref="canvas"></canvas></div>
                            <div class="absolute inset-x-0 bottom-1 text-center">
                                <p class="font-display text-2xl font-semibold leading-none">{{ $data['employee']['total'] }}</p>
                                <p class="text-[11px] text-fg-muted">Employees</p>
                            </div>
                        </div>
                        <ul class="space-y-2.5 text-sm">
                            @foreach ($data['employee']['segments'] as $s)
                                <li class="flex items-center gap-2 whitespace-nowrap">
                                    <span class="h-2.5 w-2.5 rounded-full" style="background: {{ $s['color'] }}"></span>
                                    <span class="text-fg-muted">{{ $s['label'] }} →</span>
                                    <span class="font-semibold">{{ str_pad((string) $s['value'], 2, '0', STR_PAD_LEFT) }}</span>
                                </li>
                            @endforeach
                        </ul>
                    </div>
                </section>
            </div>
        </div>

        <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
            {{-- Recent orders --}}
            <div class="lg:col-span-7">
                <section class="card p-5">
                    <div class="flex flex-wrap items-center justify-between gap-3">
                        <h2 class="font-display text-lg font-semibold">Recent Orders</h2>
                        <div class="flex items-center gap-3">
                            <div class="relative">
                                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-fg-muted"></i>
                                <input placeholder="eg: search here…" class="w-44 rounded-lg border border-border bg-bg py-1.5 pl-8 pr-3 text-xs outline-none focus:border-accent">
                            </div>
                            <a href="/orders" class="text-xs font-medium text-accent hover:text-accent-deep">View all</a>
                        </div>
                    </div>
                    @if (count($data['recentOrders']) === 0)
                        <p class="mt-6 text-sm text-fg-muted">No orders yet.</p>
                    @else
                        <div class="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                            @foreach ($data['recentOrders'] as $o)
                                <article class="rounded-xl border border-border p-3">
                                    <div class="relative h-28 w-full overflow-hidden rounded-lg bg-bg">
                                        @if ($o['image'])
                                            <img src="{{ $o['image'] }}" alt="{{ $o['customer'] }}" class="h-full w-full object-cover">
                                        @else
                                            <span class="grid h-full w-full place-items-center text-xs text-fg-muted">No image</span>
                                        @endif
                                    </div>
                                    <div class="mt-3 flex items-start justify-between gap-2">
                                        <h3 class="min-w-0 truncate text-sm font-semibold">{{ $o['customer'] }}</h3>
                                        <span class="text-xs text-fg-muted">{{ $o['line'] }}</span>
                                    </div>
                                    <dl class="mt-2 space-y-1 text-xs text-fg-muted">
                                        <div class="flex justify-between"><dt>Order ID</dt><dd class="font-medium text-fg">{{ $o['orderId'] }}</dd></div>
                                        <div class="flex justify-between"><dt>Type</dt><dd class="font-medium text-fg">{{ $o['type'] }}</dd></div>
                                    </dl>
                                    <div class="mt-3 flex items-center justify-between">
                                        <x-ops.badge :status="$o['status']" />
                                        <span class="font-display text-base font-semibold">{{ $money($o['price']) }}</span>
                                    </div>
                                </article>
                            @endforeach
                        </div>
                    @endif
                </section>
            </div>

            {{-- Sales & order types --}}
            <div class="lg:col-span-5">
                <section class="card flex h-full flex-col p-5">
                    <div class="flex items-start justify-between">
                        <h2 class="font-display text-lg font-semibold">Sales &amp; Order Types</h2>
                        <button type="button" aria-label="Open sales breakdown" class="grid h-8 w-8 place-items-center rounded-lg border border-border text-fg-muted transition-colors hover:border-accent/40 hover:text-accent">
                            <i data-lucide="arrow-up-right" class="h-4 w-4"></i>
                        </button>
                    </div>
                    <div class="mt-6 grid flex-1 grid-cols-3">
                        @foreach ($data['salesTypes'] as $i => $s)
                            <div class="{{ $i > 0 ? 'border-l border-dashed border-border pl-4' : 'pr-4' }}">
                                <p class="text-xs text-fg-muted">{{ $s['label'] }}</p>
                                <p class="mt-2 font-display text-3xl font-semibold">{{ Format::js($s['percent']) }}%</p>
                            </div>
                        @endforeach
                    </div>
                    <div class="mt-5 flex gap-1.5">
                        @foreach ($data['salesTypes'] as $i => $s)
                            <div class="h-2.5 rounded-full {{ $barColors[$i] ?? 'bg-accent' }}" style="width: {{ Format::js($s['percent']) }}%"></div>
                        @endforeach
                    </div>
                </section>
            </div>
        </div>
    </div>

    {{-- ---- Right column ---- --}}
    <div class="w-full space-y-5 xl:w-[336px] xl:shrink-0">
        {{-- Trending menu item (+ edit override) --}}
        <section class="card p-5" x-data="{ open: false, choice: @js($currentItemId ?? 'AUTO'), pending: false,
                async save() {
                    this.pending = true;
                    try { await api('/dashboard/trending', { method: 'POST', body: { itemId: this.choice === 'AUTO' ? null : this.choice } }); } catch (e) {}
                    location.reload();
                } }">
            <div class="flex items-center justify-between">
                <h2 class="font-display text-lg font-semibold">Trending Menu Item</h2>
                @if ($editable)
                    <button type="button" @click="choice = @js($currentItemId ?? 'AUTO'); open = true" aria-label="Edit trending item"
                            class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-accent-soft hover:text-accent">
                        <i data-lucide="pencil" class="h-4 w-4"></i>
                    </button>
                @endif
            </div>
            <div class="relative mt-4 h-44 w-full overflow-hidden rounded-xl">
                @if ($data['trending']['image'])
                    <img src="{{ $data['trending']['image'] }}" alt="{{ $data['trending']['name'] }}" class="absolute inset-0 h-full w-full object-cover">
                @endif
            </div>
            <div class="mt-4 flex items-start justify-between gap-3">
                <div>
                    <h3 class="font-display text-base font-semibold">{{ $data['trending']['name'] }}</h3>
                    <p class="text-xs text-fg-muted">{{ $data['trending']['subtitle'] }}</p>
                </div>
                <span class="font-display text-xl font-semibold text-accent">{{ $money($data['trending']['price']) }}</span>
            </div>
            <div class="mt-3 flex items-center gap-4 text-sm text-fg-muted">
                <span class="inline-flex items-center gap-1"><i data-lucide="star" class="h-4 w-4 fill-gold text-gold"></i>{{ Format::js($data['trending']['rating']) }}</span>
                <span class="inline-flex items-center gap-1"><i data-lucide="clock" class="h-4 w-4"></i>{{ $data['trending']['orders'] }}</span>
            </div>

            @if ($editable)
                <x-ops.modal show="open" close="open = false" title="Trending menu item">
                    <div class="space-y-4">
                        <div>
                            <label class="mb-1.5 block text-sm font-medium">Featured item</label>
                            <select x-model="choice" class="w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none focus:border-accent">
                                <option value="AUTO">Auto — most ordered</option>
                                @foreach ($menuOptions as $m)
                                    <option value="{{ $m['id'] }}">{{ $m['name'] }}</option>
                                @endforeach
                            </select>
                            <p class="mt-1 text-xs text-fg-muted">Choose a dish to feature, or Auto to use the best-seller.</p>
                        </div>
                        <div class="flex justify-end gap-3 pt-1">
                            <button type="button" @click="open = false" class="rounded-lg border border-border px-4 py-2 text-sm font-medium hover:bg-bg">Cancel</button>
                            <button type="button" @click="save()" :disabled="pending" class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent-deep disabled:opacity-60" x-text="pending ? 'Saving…' : 'Save'"></button>
                        </div>
                    </div>
                </x-ops.modal>
            @endif
        </section>

        {{-- POS activities --}}
        <section class="card p-5">
            <div class="flex items-center justify-between">
                <h2 class="font-display text-lg font-semibold">POS Activities</h2>
                <x-ops.filter-pill label="Today's" />
            </div>
            <div class="mt-4 flex items-center gap-3">
                <span class="text-sm text-fg-muted">Total Sales</span>
                <span class="text-fg-muted">→</span>
            </div>
            <div class="mt-1 flex items-center gap-3">
                <p class="font-display text-3xl font-semibold">{{ $pos['totalSales'] }}</p>
                <span class="inline-flex items-center gap-1 rounded-full bg-success-soft px-1.5 py-0.5 text-xs font-semibold text-success">
                    <i data-lucide="trending-up" class="h-3 w-3"></i>{{ $delta($pos['salesDelta']) }}
                </span>
                <span class="text-xs text-fg-muted">Since Yesterday</span>
            </div>
            <div class="mt-5 grid grid-cols-3 gap-2 border-t border-border pt-4 text-center">
                @foreach ([['Total Bills', (string) $pos['totalBills']], ['AVG Value', $pos['avgValue']], ['Peak Hour', $pos['peakHour']]] as [$l, $v])
                    <div>
                        <p class="text-xs text-fg-muted">{{ $l }}</p>
                        <p class="mt-1 font-display text-lg font-semibold">{{ $v }}</p>
                    </div>
                @endforeach
            </div>
            <p class="mt-5 text-sm font-medium">Payment Method</p>
            <div class="mt-2">
                <svg viewBox="0 0 240 132" class="w-full" role="img" aria-label="{{ $pos['payment']['cash'] }}% Cash Payment">
                    @foreach ($gauge as $l)
                        <line x1="{{ $l['x1'] }}" y1="{{ $l['y1'] }}" x2="{{ $l['x2'] }}" y2="{{ $l['y2'] }}"
                              stroke="{{ $l['dim'] ? '#e6e8ec' : $l['color'] }}" stroke-width="3" stroke-linecap="round" />
                    @endforeach
                    <text x="120" y="100" text-anchor="middle" class="fill-fg font-display" style="font-size: 30px; font-weight: 600">{{ $pos['payment']['cash'] }}%</text>
                    <text x="120" y="122" text-anchor="middle" class="fill-fg-muted" style="font-size: 12px">Cash Payment</text>
                </svg>
            </div>
            <div class="mt-2 flex items-center justify-center gap-5 text-xs text-fg-muted">
                <span class="inline-flex items-center gap-1.5"><span class="h-2.5 w-2.5 rounded-full bg-accent"></span> Card {{ $pos['payment']['card'] }}%</span>
                <span class="inline-flex items-center gap-1.5"><span class="h-2.5 w-2.5 rounded-full bg-[#cbd0d8]"></span> Online {{ $pos['payment']['online'] }}%</span>
            </div>
            <button type="button" class="mt-5 w-full rounded-xl bg-accent px-4 py-3 text-sm font-semibold text-white transition-colors hover:bg-accent-deep">View Details</button>
        </section>
    </div>
</div>
@endsection

@push('scripts')
<script>
    // Resolve "var(--color-x)" (recharts accepts CSS vars, canvas does not).
    const cssColor = (c) => {
        const m = /^var\(--color-([\w-]+)\)$/.exec(String(c).trim());
        return m ? themeColor(m[1]) : c;
    };

    document.addEventListener('alpine:init', () => {
        // CostRevenueChart.tsx — two monotone lines, highlighted active outlet, pill tooltip.
        Alpine.data('costRevenueChart', (series, activeOutlet) => ({
            chart: null,
            init() {
                this.draw();
                window.addEventListener('theme-changed', () => this.draw());
            },
            draw() {
                this.chart?.destroy();
                const accent = themeColor('accent');
                const muted = themeColor('fg-muted');
                const family = getComputedStyle(document.body).fontFamily;
                const border = themeColor('border');
                const activeIndex = series.findIndex((d) => d.outlet === activeOutlet);
                const tipEl = this.$refs.tip;
                const fmtK = (v) => `$${Math.round(v / 1000)}K`;
                const highlight = {
                    id: 'activeArea',
                    beforeDatasetsDraw(chart) {
                        if (activeIndex < 0) return;
                        const { ctx, chartArea, scales } = chart;
                        const x2 = scales.x.getPixelForValue(activeIndex);
                        // recharts: data[activeIndex - 0.5] is undefined → the area starts at the first category
                        const x1 = scales.x.getPixelForValue(0);
                        ctx.save();
                        ctx.globalAlpha = 0.06;
                        ctx.fillStyle = accent;
                        ctx.fillRect(x1, chartArea.top, x2 - x1, chartArea.bottom - chartArea.top);
                        ctx.restore();
                    },
                    afterDraw(chart) {
                        const act = chart.tooltip?.getActiveElements?.() ?? [];
                        if (!act.length) return;
                        const { ctx, chartArea } = chart;
                        const x = act[0].element.x;
                        ctx.save();
                        ctx.setLineDash([4, 4]);
                        ctx.strokeStyle = accent;
                        ctx.beginPath();
                        ctx.moveTo(x, chartArea.top);
                        ctx.lineTo(x, chartArea.bottom);
                        ctx.stroke();
                        ctx.restore();
                    },
                };
                this.chart = new Chart(this.$refs.canvas, {
                    type: 'line',
                    data: {
                        labels: series.map((d) => d.outlet),
                        datasets: [
                            { label: 'sells', data: series.map((d) => d.sells), borderColor: '#3a3a3a', backgroundColor: '#3a3a3a', borderWidth: 2.5, pointRadius: 0, pointHoverRadius: 5, cubicInterpolationMode: 'monotone' },
                            { label: 'cost', data: series.map((d) => d.cost), borderColor: accent, backgroundColor: accent, borderWidth: 2.5, pointRadius: 0, pointHoverRadius: 5, cubicInterpolationMode: 'monotone' },
                        ],
                    },
                    options: {
                        maintainAspectRatio: false,
                        animation: false,
                        layout: { padding: { top: 20, right: 8 } },
                        interaction: { mode: 'index', intersect: false },
                        plugins: {
                            legend: { display: false },
                            tooltip: {
                                enabled: false,
                                external: ({ chart, tooltip }) => {
                                    if (!tooltip.opacity) { tipEl.style.opacity = 0; return; }
                                    tipEl.innerHTML = tooltip.dataPoints.map((p) =>
                                        `<span class="rounded-full px-3 py-1 text-xs font-semibold text-white shadow-pop" style="background:${p.dataset.label === 'cost' ? accent : '#3a3a3a'}">${fmtK(p.raw)}</span>`).join('');
                                    tipEl.style.opacity = 1;
                                    tipEl.style.left = `${Math.min(tooltip.caretX + 12, chart.width - 70)}px`;
                                    tipEl.style.top = `${Math.max(0, tooltip.caretY - 20)}px`;
                                },
                            },
                        },
                        scales: {
                            x: { grid: { display: false }, border: { display: false }, ticks: { color: muted, font: { size: 11, family }, autoSkip: false, maxRotation: 0 } },
                            y: {
                                min: 0, suggestedMax: 15000,
                                grid: { color: border }, border: { display: false },
                                ticks: { stepSize: 3000, color: muted, font: { size: 11, family }, callback: (v) => `$${v / 1000}K` },
                            },
                        },
                    },
                    plugins: [highlight],
                });
            },
        }));

        // EmployeeGauge.tsx — semicircle doughnut.
        Alpine.data('employeeGauge', (segments) => ({
            chart: null,
            init() {
                this.draw();
                window.addEventListener('theme-changed', () => this.draw());
            },
            draw() {
                this.chart?.destroy();
                this.chart = new Chart(this.$refs.canvas, {
                    type: 'doughnut',
                    data: {
                        labels: segments.map((s) => s.label),
                        datasets: [{ data: segments.map((s) => s.value), backgroundColor: segments.map((s) => cssColor(s.color)), borderWidth: 0, borderRadius: 6, spacing: 3 }],
                    },
                    options: {
                        maintainAspectRatio: false,
                        animation: false,
                        rotation: -90,
                        circumference: 180,
                        cutout: "70%",
                        // recharts: outer 100 / inner 70, centre at 95% height → arc sits at the bottom
                        layout: { padding: { top: 38, bottom: 8 } },
                        plugins: { legend: { display: false }, tooltip: { enabled: false } },
                    },
                });
            },
        }));

        // TopCategories.tsx editor — three rows seeded from the current values.
        Alpine.data('topCategoriesEditor', (current, options) => ({
            open: false,
            pending: false,
            rows: [],
            options,
            openEditor() {
                this.rows = [0, 1, 2].map((i) => ({
                    name: current[i]?.name ?? options[i] ?? options[0] ?? '',
                    percent: current[i]?.percent ?? 0,
                }));
                this.open = true;
            },
            async save(reset) {
                this.pending = true;
                const categories = reset ? null : this.rows.filter((r) => r.name).map((r) => ({ name: r.name, percent: Number(r.percent) || 0 }));
                try { await api('/dashboard/top-categories', { method: 'POST', body: { categories } }); } catch (e) {}
                location.reload();
            },
        }));
    });
</script>
@endpush
