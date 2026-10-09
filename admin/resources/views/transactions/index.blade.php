@extends('layouts.app')

@section('content')
<x-biz.helpers />
<div x-data="transactionsView(@js($transactions))" class="space-y-5">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <x-biz.stat label="Transactions" icon="receipt" x-text="stats.count" />
        <x-biz.stat label="Total Amount" icon="dollar-sign" x-text="bizMoney(stats.total)" />
        <x-biz.stat label="Gateway Payments" icon="credit-card" x-text="stats.gatewayCount" />
        <x-biz.stat label="Gateway Amount" icon="dollar-sign" x-text="bizMoney(stats.gatewayTotal)" />
    </div>

    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="s in ['ALL', 'Order', 'Gift Card', 'Table']" :key="s">
                <button type="button" @click="source = s"
                        class="rounded-pill px-3.5 py-1.5 text-sm font-medium transition-colors"
                        :class="source === s ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"
                        x-text="s === 'ALL' ? 'All' : s"></button>
            </template>
        </div>
        <div class="flex items-center gap-3">
            <select x-model="method" class="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg-muted outline-none focus:border-accent">
                <option value="ALL">All methods</option>
                <template x-for="m in methods" :key="m"><option :value="m" x-text="m"></option></template>
            </select>
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" placeholder="Search ref, customer, payment id…"
                       class="w-56 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
            </div>
            <button type="button" @click="exportCsv()"
                    class="inline-flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm font-semibold transition-colors hover:bg-bg">
                <i data-lucide="download" class="h-4 w-4"></i> Export
            </button>
        </div>
    </div>

    <div class="card overflow-x-auto">
        <table class="w-full text-sm">
            <thead>
            <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
                <th class="px-5 py-3 font-medium">Source</th>
                <th class="px-5 py-3 font-medium">Reference</th>
                <th class="px-5 py-3 font-medium">Customer</th>
                <th class="px-5 py-3 font-medium">Method</th>
                <th class="px-5 py-3 font-medium">Amount</th>
                <th class="px-5 py-3 font-medium">Date</th>
            </tr>
            </thead>
            <tbody>
            <template x-for="t in filtered" :key="t.id">
                <tr class="border-b border-border last:border-0 hover:bg-bg/60">
                    <td class="px-5 py-3">
                        <span class="rounded-md px-2 py-0.5 text-xs font-semibold" :class="SOURCE_CLS[t.source]" x-text="t.source"></span>
                    </td>
                    <td class="px-5 py-3 font-medium">
                        <span x-text="t.reference"></span>
                        <p x-show="t.paymentId" class="font-mono text-[10px] text-fg-muted" x-text="t.paymentId"></p>
                    </td>
                    <td class="px-5 py-3 text-fg-muted" x-text="t.customer"></td>
                    <td class="px-5 py-3">
                        <span x-show="GATEWAYS.includes(t.method)" class="rounded-pill bg-[#3395ff]/15 px-2 py-0.5 text-xs font-semibold text-[#3395ff]" x-text="t.method"></span>
                        <span x-show="!GATEWAYS.includes(t.method)" class="text-fg-muted" x-text="t.method"></span>
                    </td>
                    <td class="px-5 py-3 font-medium" x-text="bizMoney(t.amount)"></td>
                    <td class="px-5 py-3 text-fg-muted" x-text="bizDate(t.date, 'MMM d, h:mm a')"></td>
                </tr>
            </template>
            <tr x-show="filtered.length === 0" x-cloak>
                <td colspan="6" class="px-5 py-12 text-center text-sm text-fg-muted">No transactions match your filters.</td>
            </tr>
            </tbody>
        </table>
    </div>
</div>
@endsection

@push('scripts')
<script>
    function transactionsView(transactions) {
        const GATEWAYS = ['Razorpay', 'Stripe', 'PayPal'];
        return {
            transactions,
            GATEWAYS,
            SOURCE_CLS: {
                Order: 'bg-accent-soft text-accent',
                'Gift Card': 'bg-gold/15 text-gold-deep',
                Table: 'bg-info-soft text-info',
            },
            source: 'ALL',
            method: 'ALL',
            query: '',
            get methods() {
                return Array.from(new Set(this.transactions.map((t) => t.method))).sort();
            },
            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.transactions.filter((t) =>
                    (this.source === 'ALL' || t.source === this.source) &&
                    (this.method === 'ALL' || t.method === this.method) &&
                    (q === '' || t.reference.toLowerCase().includes(q) || t.customer.toLowerCase().includes(q) ||
                        (t.paymentId ?? '').toLowerCase().includes(q)));
            },
            get stats() {
                const f = this.filtered;
                const gateway = f.filter((t) => GATEWAYS.includes(t.method));
                return {
                    count: f.length,
                    total: f.reduce((s, t) => s + t.amount, 0),
                    gatewayCount: gateway.length,
                    gatewayTotal: gateway.reduce((s, t) => s + t.amount, 0),
                };
            },
            exportCsv() {
                const header = ['Date', 'Source', 'Reference', 'Customer', 'Method', 'Amount', 'Status', 'PaymentId'];
                const data = this.filtered.map((t) => [
                    t.date.slice(0, 19).replace('T', ' '), t.source, t.reference, t.customer, t.method, t.amount, t.status, t.paymentId ?? '',
                ]);
                bizCsv(`transactions-${new Date().toISOString().slice(0, 10)}.csv`, [header, ...data]);
            },
        };
    }
</script>
@endpush
