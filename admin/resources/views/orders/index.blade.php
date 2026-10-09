@extends('layouts.app')

@section('content')
<div class="space-y-5" x-data="ordersManager(@js($orders))">
    {{-- Summary stats --}}
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        @foreach ([['Total Orders', 'stats.total', 'receipt'], ['Completed', 'stats.completed', 'circle-check'], ['Canceled', 'stats.canceled', 'circle-x'], ['Revenue', 'formatCurrency(stats.revenue)', 'dollar-sign']] as [$label, $expr, $icon])
            <div class="card flex items-center gap-3 p-4">
                <span class="grid h-10 w-10 place-items-center rounded-lg bg-accent-soft text-accent"><i data-lucide="{{ $icon }}" class="h-5 w-5"></i></span>
                <div>
                    <p class="text-xs text-fg-muted">{{ $label }}</p>
                    <p class="font-display text-xl font-semibold" x-text="{{ $expr }}"></p>
                </div>
            </div>
        @endforeach
    </div>

    {{-- Filters --}}
    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="s in STATUS_FILTERS" :key="s">
                <button type="button" @click="status = s" x-text="s === 'ALL' ? 'All' : s.toLowerCase()"
                        class="rounded-pill px-3.5 py-1.5 text-sm font-medium capitalize transition-colors"
                        :class="status === s ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"></button>
            </template>
        </div>
        <div class="flex items-center gap-3">
            <select x-model="channel" class="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg-muted outline-none focus:border-accent">
                <option value="ALL">All channels</option>
                <option value="ONLINE">Online</option>
                <option value="POS">In-house (POS)</option>
            </select>
            <select x-model="type" class="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg-muted outline-none focus:border-accent">
                <option value="ALL">All types</option>
                <option value="DINE_IN">Dine-in</option>
                <option value="DELIVERY">Delivery</option>
                <option value="PICKUP">Pick-up</option>
            </select>
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" placeholder="Search order # or customer…"
                       class="w-56 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
            </div>
        </div>
    </div>

    {{-- Table --}}
    <div class="card overflow-x-auto">
        <table class="w-full text-sm">
            <thead>
                <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
                    <th class="px-5 py-3 font-medium">Order</th>
                    <th class="px-5 py-3 font-medium">Customer</th>
                    <th class="px-5 py-3 font-medium">Type</th>
                    <th class="px-5 py-3 font-medium">Items</th>
                    <th class="px-5 py-3 font-medium">Total</th>
                    <th class="px-5 py-3 font-medium">Time</th>
                    <th class="px-5 py-3 font-medium">Status</th>
                    <th class="px-5 py-3 text-right font-medium">View</th>
                </tr>
            </thead>
            <tbody>
                <tr x-show="filtered.length === 0">
                    <td colspan="8" class="px-5 py-12 text-center text-sm text-fg-muted">No orders match your filters.</td>
                </tr>
                <template x-for="o in filtered" :key="o.id">
                    <tr class="cursor-pointer border-b border-border last:border-0 hover:bg-bg/60" @click="active = o">
                        <td class="px-5 py-3 font-medium">
                            <span class="flex flex-wrap items-center gap-2">
                                <span x-text="o.number"></span>
                                <template x-if="o.tableNumber">
                                    <span class="rounded-pill bg-gold/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-gold-deep" x-text="'Table ' + o.tableNumber"></span>
                                </template>
                                <template x-if="o.channel === 'ONLINE'">
                                    <span class="rounded-pill bg-accent-soft px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-accent">Online</span>
                                </template>
                                <template x-if="o.paymentProvider">
                                    <span class="rounded-pill bg-[#3395ff]/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[#3395ff]" x-text="gatewayLabel(o.paymentProvider)"></span>
                                </template>
                            </span>
                        </td>
                        <td class="px-5 py-3" x-text="o.customer"></td>
                        <td class="px-5 py-3 text-fg-muted" x-text="TYPE_LABELS[o.type]"></td>
                        <td class="px-5 py-3 text-fg-muted" x-text="o.items.reduce((n, it) => n + it.qty, 0)"></td>
                        <td class="px-5 py-3 font-medium" x-text="formatCurrency(o.total)"></td>
                        <td class="px-5 py-3 text-fg-muted" x-text="fmtDate(o.createdAt, 'h:mm a')"></td>
                        <td class="px-5 py-3">
                            <span class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold" :class="STATUS_STYLES[o.status]">
                                <span class="h-1.5 w-1.5 rounded-full bg-current"></span><span x-text="STATUS_LABELS[o.status]"></span>
                            </span>
                        </td>
                        <td class="px-5 py-3">
                            <div class="flex justify-end">
                                <span class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted"><i data-lucide="eye" class="h-4 w-4"></i></span>
                            </div>
                        </td>
                    </tr>
                </template>
            </tbody>
        </table>
    </div>

    <p class="text-xs text-fg-muted">
        Showing <span x-text="filtered.length"></span> of <span x-text="orders.length"></span> orders. Status changes are in-session until the
        MySQL data layer is connected.
    </p>

    {{-- Order detail --}}
    <x-ops.modal show="active" close="active = null" title-expr="active?.number">
        <template x-if="active">
            <div class="space-y-5">
                <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                        <span class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold" :class="STATUS_STYLES[active.status]">
                            <span class="h-1.5 w-1.5 rounded-full bg-current"></span><span x-text="STATUS_LABELS[active.status]"></span>
                        </span>
                        <template x-if="active.channel === 'ONLINE'">
                            <span class="rounded-pill bg-accent-soft px-2.5 py-0.5 text-xs font-semibold text-accent">Online</span>
                        </template>
                        <template x-if="active.paymentProvider">
                            <span class="rounded-pill bg-[#3395ff]/15 px-2.5 py-0.5 text-xs font-semibold text-[#3395ff]" x-text="gatewayLabel(active.paymentProvider)"></span>
                        </template>
                    </div>
                    <span class="text-sm text-fg-muted" x-text="fmtDate(active.createdAt, 'MMM d, h:mm a')"></span>
                </div>

                {{-- Step-wise status progress --}}
                <div class="rounded-xl border border-border px-4 py-4">
                    <ol class="flex items-start">
                        <template x-for="(s, i) in ORDER_FLOW" :key="s">
                            <li class="flex flex-1 items-start last:flex-none">
                                <div class="flex flex-col items-center gap-1.5">
                                    <span class="grid h-8 w-8 place-items-center rounded-full border text-xs font-semibold transition-colors"
                                          :class="step(i) === 'current' ? 'border-accent bg-accent text-white ring-4 ring-accent-soft' : (step(i) === 'done' ? 'border-accent bg-accent text-white' : 'border-border bg-surface text-fg-muted')">
                                        <span x-show="step(i) === 'done'"><i data-lucide="check" class="h-4 w-4"></i></span>
                                        <span x-show="step(i) !== 'done'" x-text="i + 1"></span>
                                    </span>
                                    <span class="text-center text-[11px] font-medium leading-tight" :class="step(i) !== 'todo' ? 'text-fg' : 'text-fg-muted'" x-text="STATUS_LABELS[s]"></span>
                                </div>
                                <template x-if="i < ORDER_FLOW.length - 1">
                                    <span class="mx-1 mt-4 h-0.5 flex-1 rounded transition-colors" :class="i < flowIndex() ? 'bg-accent' : 'bg-border'"></span>
                                </template>
                            </li>
                        </template>
                    </ol>
                    <template x-if="active.status === 'CANCELED'">
                        <div class="mt-3 flex items-center gap-2 rounded-lg border border-danger/40 bg-danger-soft px-3 py-2 text-sm font-medium text-danger">
                            <i data-lucide="x" class="h-4 w-4"></i> This order was canceled.
                        </div>
                    </template>
                </div>

                <dl class="grid grid-cols-2 gap-3 text-sm">
                    <template x-for="[k, v] in detailRows()" :key="k">
                        <div class="rounded-lg border border-border px-3 py-2">
                            <dt class="text-xs text-fg-muted" x-text="k"></dt>
                            <dd class="mt-0.5 font-medium break-words" x-text="v"></dd>
                        </div>
                    </template>
                </dl>

                {{-- Take-away scheduling (online orders) --}}
                <template x-if="active.scheduleType">
                    <div class="rounded-lg border border-accent/30 bg-accent-soft/50 px-3 py-2.5 text-sm">
                        <p class="text-xs font-semibold uppercase tracking-wide text-accent" x-text="(active.scheduleType === 'LATER' ? 'Scheduled' : 'ASAP') + ' pickup'"></p>
                        <p class="mt-0.5 font-medium"
                           x-text="active.scheduleType === 'LATER' && active.scheduleDate ? fmtDate(active.scheduleDate, 'EEE, MMM d') + (active.scheduleTime ? ' · ' + active.scheduleTime : '') : 'As soon as possible'"></p>
                    </div>
                </template>

                <template x-if="active.notes">
                    <div class="rounded-lg border border-border px-3 py-2 text-sm">
                        <p class="text-xs text-fg-muted">Notes</p>
                        <p class="mt-0.5" x-text="active.notes"></p>
                    </div>
                </template>

                {{-- Items --}}
                <div class="rounded-xl border border-border">
                    <div class="border-b border-border px-4 py-2 text-xs uppercase tracking-wide text-fg-muted">Items</div>
                    <ul class="divide-y divide-border">
                        <template x-for="it in active.items" :key="it.name">
                            <li class="flex items-center justify-between px-4 py-2.5 text-sm">
                                <span><span class="font-medium" x-text="it.qty + '×'"></span> <span x-text="it.name"></span></span>
                                <span class="text-fg-muted" x-text="formatCurrency(it.qty * it.price)"></span>
                            </li>
                        </template>
                    </ul>
                    <div class="flex items-center justify-between border-t border-border px-4 py-3">
                        <span class="text-sm font-medium">Total</span>
                        <span class="font-display text-lg font-semibold" x-text="formatCurrency(active.total)"></span>
                    </div>
                </div>

                {{-- Transitions --}}
                <div x-show="nextStatuses(active.status).length > 0">
                    <p class="mb-2 text-xs uppercase tracking-wide text-fg-muted">Update status</p>
                    <div class="flex flex-wrap gap-2">
                        <template x-for="s in nextStatuses(active.status)" :key="s">
                            <button type="button" @click="changeStatus(active.id, s)" x-text="'Mark ' + STATUS_LABELS[s]"
                                    class="rounded-lg px-4 py-2 text-sm font-semibold transition-colors"
                                    :class="s === 'CANCELED' ? 'border border-danger/40 text-danger hover:bg-danger-soft' : 'bg-accent text-white hover:bg-accent-deep'"></button>
                        </template>
                    </div>
                </div>
                <p x-show="nextStatuses(active.status).length === 0" class="text-sm text-fg-muted"
                   x-text="'This order is ' + STATUS_LABELS[active.status] + ' — no further actions.'"></p>
            </div>
        </template>
    </x-ops.modal>
</div>
@endsection

@push('scripts')
<script>
    document.addEventListener('alpine:init', () => {
        const ORDER_FLOW = ['PENDING', 'PREPARING', 'READY', 'COMPLETED'];
        const TYPE_LABELS = { DINE_IN: 'Dine-in', DELIVERY: 'Delivery', PICKUP: 'Pick-up' };
        const STATUS_LABELS = { PENDING: 'Pending', PREPARING: 'Preparing', READY: 'Ready', COMPLETED: 'Completed', CANCELED: 'Canceled' };
        const STATUS_STYLES = {
            PENDING: 'bg-bg text-fg-muted', PREPARING: 'bg-warn-soft text-warn', READY: 'bg-info-soft text-info',
            COMPLETED: 'bg-success-soft text-success', CANCELED: 'bg-danger-soft text-danger',
        };
        const gatewayLabel = (p) => (p === 'stripe' ? 'Stripe' : p === 'paypal' ? 'PayPal' : 'Razorpay');

        // OrdersManager.tsx
        Alpine.data('ordersManager', (initial) => ({
            orders: initial,
            status: 'ALL',
            type: 'ALL',
            channel: 'ALL',
            query: '',
            active: null,
            STATUS_FILTERS: ['ALL', ...ORDER_FLOW, 'CANCELED'],
            ORDER_FLOW, TYPE_LABELS, STATUS_LABELS, STATUS_STYLES, gatewayLabel,
            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.orders.filter((o) =>
                    (this.status === 'ALL' || o.status === this.status) &&
                    (this.type === 'ALL' || o.type === this.type) &&
                    (this.channel === 'ALL' || o.channel === this.channel) &&
                    (q === '' || o.number.toLowerCase().includes(q) || o.customer.toLowerCase().includes(q)));
            },
            get stats() {
                const completed = this.orders.filter((o) => o.status === 'COMPLETED');
                return {
                    total: this.orders.length,
                    completed: completed.length,
                    canceled: this.orders.filter((o) => o.status === 'CANCELED').length,
                    revenue: completed.reduce((s, o) => s + o.total, 0),
                };
            },
            nextStatuses(status) {
                if (status === 'COMPLETED' || status === 'CANCELED') return [];
                const idx = ORDER_FLOW.indexOf(status);
                const forward = idx >= 0 && idx < ORDER_FLOW.length - 1 ? [ORDER_FLOW[idx + 1]] : [];
                return [...forward, 'CANCELED'];
            },
            flowIndex() {
                return this.active.status === 'CANCELED' ? -1 : ORDER_FLOW.indexOf(this.active.status);
            },
            step(i) {
                const cur = this.flowIndex();
                if (cur < 0) return 'todo';
                return i < cur ? 'done' : i === cur ? 'current' : 'todo';
            },
            detailRows() {
                const o = this.active;
                return [
                    ['Customer', o.customer],
                    ['Type', TYPE_LABELS[o.type]],
                    ...(o.tableNumber ? [['Table', `Table ${o.tableNumber}`]] : []),
                    ['Outlet', o.outlet],
                    ['Payment', o.paymentMethod],
                    ...(o.customerPhone ? [['Phone', o.customerPhone]] : []),
                    ...(o.customerEmail ? [['Email', o.customerEmail]] : []),
                    ...(o.razorpayPaymentId ? [[`${gatewayLabel(o.paymentProvider)} Payment`, o.razorpayPaymentId]] : []),
                ];
            },
            changeStatus(id, next) {
                this.orders = this.orders.map((o) => (o.id === id ? { ...o, status: next } : o));
                if (this.active && this.active.id === id) this.active = { ...this.active, status: next };
                api(`/orders/${id}/status`, { method: 'PATCH', body: { status: next } }).catch((e) => toast(e.message, 'error'));
            },
        }));
    });
</script>
@endpush
