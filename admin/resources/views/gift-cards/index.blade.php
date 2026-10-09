@extends('layouts.app')

@php
    // GiftCardForm.tsx field/label classes
    $field = 'w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none transition-colors focus:border-accent';
    $label = 'mb-1.5 block text-sm font-medium';
@endphp

@section('content')
<x-biz.helpers />
<div x-data="giftCardsManager(@js($cards))" x-effect="filtered; bizIcons()" class="space-y-5">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <x-biz.stat label="Total Purchases" icon="gift" x-text="cards.length" />
        <x-biz.stat label="Total Value" icon="dollar-sign" x-text="bizMoney(cards.filter(c => c.paymentStatus === 'PAID').reduce((s, c) => s + c.amount, 0))" />
        <x-biz.stat label="Active" icon="circle-check" x-text="cards.filter(c => c.status === 'ACTIVE').length" />
        <x-biz.stat label="Redeemed" icon="clock" x-text="cards.filter(c => c.status === 'REDEEMED').length" />
    </div>

    {{-- Toolbar --}}
    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="s in ['ALL', 'PENDING_PAYMENT', 'PAID', 'ACTIVE', 'REDEEMED', 'EXPIRED', 'CANCELLED']" :key="s">
                <button type="button" @click="status = s"
                        class="rounded-pill px-3 py-1.5 text-sm font-medium transition-colors"
                        :class="status === s ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"
                        x-text="s === 'ALL' ? 'All' : STATUS_LABELS[s]"></button>
            </template>
        </div>
        <div class="flex items-center gap-3">
            <select x-model="kind" class="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg-muted outline-none focus:border-accent">
                <option value="ALL">All types</option>
                <option value="GIFT_CARD">Gift Cards</option>
                <option value="COUPON">Coupons</option>
            </select>
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" placeholder="Search code, name, email…"
                       class="w-52 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
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
                <th class="px-5 py-3 font-medium">Code</th>
                <th class="px-5 py-3 font-medium">Customer</th>
                <th class="px-5 py-3 font-medium">Type</th>
                <th class="px-5 py-3 font-medium">Amount</th>
                <th class="px-5 py-3 font-medium">Payment</th>
                <th class="px-5 py-3 font-medium">Status</th>
                <th class="px-5 py-3 font-medium">Created</th>
                <th class="px-5 py-3 text-right font-medium">Actions</th>
            </tr>
            </thead>
            <tbody>
            <template x-for="c in filtered" :key="c.id">
                {{-- Spent / terminal coupons — dim the row to read as inactive. --}}
                <tr class="border-b border-border last:border-0 hover:bg-bg/60"
                    :class="['REDEEMED', 'EXPIRED', 'CANCELLED'].includes(c.status) && 'opacity-50'">
                    <td class="px-5 py-3 font-mono text-xs font-semibold" x-text="c.code"></td>
                    <td class="px-5 py-3">
                        <p class="font-medium" x-text="c.customerName"></p>
                        <p class="truncate text-xs text-fg-muted" x-text="c.customerEmail || '—'"></p>
                    </td>
                    <td class="px-5 py-3 text-fg-muted" x-text="KIND_LABELS[c.kind]"></td>
                    <td class="px-5 py-3 font-medium" x-text="bizMoney(c.amount)"></td>
                    <td class="px-5 py-3 text-fg-muted" x-text="PAYMENT_LABELS[c.paymentStatus]"></td>
                    <td class="px-5 py-3">
                        <span class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold" :class="STATUS_STYLES[c.status]">
                            <span class="h-1.5 w-1.5 rounded-full bg-current"></span>
                            <span x-text="STATUS_LABELS[c.status]"></span>
                        </span>
                    </td>
                    <td class="px-5 py-3 text-fg-muted" x-text="bizDate(c.createdAt, 'MMM d, yyyy')"></td>
                    <td class="px-5 py-3">
                        <div class="flex items-center justify-end gap-1.5">
                            <button type="button" @click="view = c" aria-label="View" class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted hover:bg-accent-soft hover:text-accent"><i data-lucide="eye" class="h-4 w-4"></i></button>
                            <button type="button" @click="openEdit(c)" aria-label="Edit" class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted hover:bg-accent-soft hover:text-accent"><i data-lucide="pencil" class="h-4 w-4"></i></button>
                            <button type="button" @click="remove(c)" aria-label="Delete" class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted hover:bg-danger-soft hover:text-danger"><i data-lucide="trash-2" class="h-4 w-4"></i></button>
                        </div>
                    </td>
                </tr>
            </template>
            <tr x-show="filtered.length === 0" x-cloak>
                <td colspan="8" class="px-5 py-12 text-center text-sm text-fg-muted">No purchases match your filters.</td>
            </tr>
            </tbody>
        </table>
    </div>

    {{-- View detail --}}
    <x-biz.modal show="!!view" close="view = null" title-expr="view ? view.code : ''">
        <template x-if="view">
            <div class="space-y-5">
                <div class="flex items-center justify-between">
                    <span class="rounded-full bg-accent-soft px-2.5 py-1 text-xs font-semibold text-accent" x-text="KIND_LABELS[view.kind]"></span>
                    <span class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold" :class="STATUS_STYLES[view.status]">
                        <span class="h-1.5 w-1.5 rounded-full bg-current"></span>
                        <span x-text="STATUS_LABELS[view.status]"></span>
                    </span>
                </div>

                <div class="rounded-xl border border-gold/30 bg-gold/10 px-5 py-4 text-center">
                    <p class="text-xs uppercase tracking-[0.2em] text-fg-muted">Code</p>
                    <p class="mt-1 font-mono text-2xl font-bold tracking-widest" x-text="view.code"></p>
                    <p class="mt-1 font-display text-xl font-semibold" x-text="bizMoney(view.amount)"></p>
                </div>

                <dl class="grid grid-cols-2 gap-3 text-sm">
                    <template x-for="[k, v] in detailRows(view)" :key="k">
                        <div class="rounded-lg border border-border px-3 py-2">
                            <dt class="text-xs text-fg-muted" x-text="k"></dt>
                            <dd class="mt-0.5 break-words font-medium" x-text="v"></dd>
                        </div>
                    </template>
                </dl>

                <div x-show="view.message" class="rounded-lg border border-border px-3 py-2 text-sm">
                    <p class="text-xs text-fg-muted">Message</p>
                    <p class="mt-0.5 italic" x-text="`“${view.message}”`"></p>
                </div>

                <div>
                    <p class="mb-2 text-xs uppercase tracking-wide text-fg-muted">Update status</p>
                    <div class="flex flex-wrap gap-2">
                        <template x-for="a in QUICK_ACTIONS.filter(a => a.status !== view.status)" :key="a.status">
                            <button type="button" @click="changeStatus(view, a.status)"
                                    class="rounded-lg px-4 py-2 text-sm font-semibold transition-colors"
                                    :class="a.danger ? 'border border-danger/40 text-danger hover:bg-danger-soft' : 'bg-accent text-white hover:bg-accent-deep'"
                                    x-text="a.label"></button>
                        </template>
                    </div>
                </div>
            </div>
        </template>
    </x-biz.modal>

    {{-- Edit --}}
    <x-biz.modal show="!!editing" close="editing = null" title-expr="editing ? `Edit ${editing.code}` : ''">
        <form @submit.prevent="submitEdit()" class="space-y-4" novalidate>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Customer name</label>
                    <input x-model="form.customerName" class="{{ $field }}">
                    <p x-show="errors.customerName" x-text="errors.customerName" class="mt-1 text-xs text-danger"></p>
                </div>
                <div>
                    <label class="{{ $label }}">Customer email</label>
                    <input x-model="form.customerEmail" class="{{ $field }}">
                    <p x-show="errors.customerEmail" x-text="errors.customerEmail" class="mt-1 text-xs text-danger"></p>
                </div>
            </div>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Type</label>
                    <select x-model="form.kind" class="{{ $field }} appearance-none">
                        <option value="GIFT_CARD">Gift Card</option>
                        <option value="COUPON">Coupon</option>
                    </select>
                </div>
                <div>
                    <label class="{{ $label }}">Amount ($)</label>
                    <input type="number" step="0.01" x-model="form.amount" class="{{ $field }}">
                    <p x-show="errors.amount" x-text="errors.amount" class="mt-1 text-xs text-danger"></p>
                </div>
            </div>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Status</label>
                    <select x-model="form.status" class="{{ $field }} appearance-none">
                        <template x-for="s in ['PENDING_PAYMENT', 'PAID', 'ACTIVE', 'REDEEMED', 'EXPIRED', 'CANCELLED']" :key="s">
                            <option :value="s" :selected="s === form.status" x-text="STATUS_LABELS[s]"></option>
                        </template>
                    </select>
                </div>
                <div>
                    <label class="{{ $label }}">Payment</label>
                    <select x-model="form.paymentStatus" class="{{ $field }} appearance-none">
                        <option value="PENDING">Pending</option>
                        <option value="PAID">Paid</option>
                        <option value="FAILED">Failed</option>
                    </select>
                </div>
            </div>
            <div>
                <label class="{{ $label }}">Expiry date <span class="font-normal text-fg-muted">(optional)</span></label>
                <input type="date" x-model="form.expiryDate" class="{{ $field }}">
            </div>
            <div class="flex justify-end gap-3 pt-2">
                <button type="button" @click="editing = null" class="rounded-lg border border-border px-4 py-2 text-sm font-medium transition-colors hover:bg-bg">
                    Cancel
                </button>
                <button type="submit" :disabled="saving" class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep disabled:opacity-60">
                    Save changes
                </button>
            </div>
        </form>
    </x-biz.modal>
</div>
@endsection

@push('scripts')
<script>
    function giftCardsManager(initial) {
        const KIND_LABELS = { GIFT_CARD: 'Gift Card', COUPON: 'Coupon' };
        const STATUS_LABELS = {
            PENDING_PAYMENT: 'Pending Payment', PAID: 'Paid', ACTIVE: 'Active',
            REDEEMED: 'Redeemed', EXPIRED: 'Expired', CANCELLED: 'Cancelled',
        };
        const PAYMENT_LABELS = { PENDING: 'Pending', PAID: 'Paid', FAILED: 'Failed' };
        const gatewayLabel = (p) => (p === 'stripe' ? 'Stripe' : p === 'paypal' ? 'PayPal' : 'Razorpay');
        return {
            cards: initial,
            KIND_LABELS,
            STATUS_LABELS,
            PAYMENT_LABELS,
            STATUS_STYLES: {
                PENDING_PAYMENT: 'bg-warn-soft text-warn',
                PAID: 'bg-info-soft text-info',
                ACTIVE: 'bg-success-soft text-success',
                REDEEMED: 'bg-accent-soft text-accent',
                EXPIRED: 'bg-bg text-fg-muted',
                CANCELLED: 'bg-danger-soft text-danger',
            },
            // Quick status transitions available from the detail view.
            QUICK_ACTIONS: [
                { status: 'ACTIVE', label: 'Activate' },
                { status: 'REDEEMED', label: 'Mark Redeemed' },
                { status: 'EXPIRED', label: 'Expire' },
                { status: 'CANCELLED', label: 'Cancel', danger: true },
            ],
            status: 'ALL',
            kind: 'ALL',
            query: '',
            view: null,
            editing: null,
            saving: false,
            form: {},
            errors: {},

            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.cards.filter((c) =>
                    (this.status === 'ALL' || c.status === this.status) &&
                    (this.kind === 'ALL' || c.kind === this.kind) &&
                    (q === '' || c.code.toLowerCase().includes(q) || c.customerName.toLowerCase().includes(q) ||
                        (c.customerEmail || '').toLowerCase().includes(q)));
            },
            detailRows(v) {
                const rows = [
                    ['Customer', v.customerName],
                    ['Email', v.customerEmail || '—'],
                    ['Payment', PAYMENT_LABELS[v.paymentStatus]],
                    ['Expiry', v.expiryDate ?? 'No expiry'],
                    ['Created', bizDate(v.createdAt, 'MMM d, yyyy')],
                ];
                if (v.razorpayPaymentId) rows.push([`${gatewayLabel(v.paymentProvider)} Payment`, v.razorpayPaymentId]);
                return rows;
            },
            exportCsv() {
                const header = ['Code', 'Type', 'Customer', 'Email', 'Amount', 'Payment', 'Status', 'Expiry', 'Created'];
                const data = this.filtered.map((r) => [
                    r.code, KIND_LABELS[r.kind], r.customerName, r.customerEmail, Number(r.amount).toFixed(2),
                    PAYMENT_LABELS[r.paymentStatus], STATUS_LABELS[r.status], r.expiryDate ?? '', r.createdAt.slice(0, 10),
                ]);
                bizCsv(`gift-cards-${new Date().toISOString().slice(0, 10)}.csv`, [header, ...data]);
            },
            async changeStatus(card, next) {
                const prev = card.status;
                card.status = next;
                try { await api(`/gift-cards/${card.id}/status`, { method: 'PATCH', body: { status: next } }); }
                catch (err) { card.status = prev; toast(err.message, 'error'); }
            },
            async remove(c) {
                if (!confirm(`Delete ${c.code}?`)) return;
                const before = this.cards;
                this.cards = this.cards.filter((x) => x.id !== c.id);
                try { await api(`/gift-cards/${c.id}`, { method: 'DELETE' }); }
                catch (err) { this.cards = before; toast(err.message, 'error'); }
            },
            openEdit(c) {
                this.form = {
                    customerName: c.customerName,
                    customerEmail: c.customerEmail,
                    kind: c.kind,
                    amount: c.amount,
                    status: c.status,
                    paymentStatus: c.paymentStatus,
                    expiryDate: c.expiryDate ?? '',
                };
                this.errors = {};
                this.editing = c;
            },
            validate() {
                const f = this.form, errs = {};
                if (String(f.customerName).trim().length < 2) errs.customerName = 'Name is required';
                if (f.customerEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.customerEmail)) errs.customerEmail = 'Invalid email';
                if (!(Number(f.amount) > 0)) errs.amount = 'Amount must be positive';
                this.errors = errs;
                return Object.keys(errs).length === 0;
            },
            async submitEdit() {
                if (!this.editing || !this.validate()) return;
                const values = { ...this.form, amount: Number(this.form.amount) };
                this.saving = true;
                try {
                    await api(`/gift-cards/${this.editing.id}`, { method: 'PUT', body: values });
                    Object.assign(this.editing, {
                        customerName: values.customerName,
                        customerEmail: values.customerEmail || '',
                        kind: values.kind,
                        amount: values.amount,
                        status: values.status,
                        paymentStatus: values.paymentStatus,
                        expiryDate: values.expiryDate || undefined,
                    });
                    this.editing = null;
                } catch (err) {
                    toast(err.message, 'error');
                } finally {
                    this.saving = false;
                }
            },
        };
    }
</script>
@endpush
