@extends('layouts.app')

@php
    $input = 'w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-accent';
    $adjInput = 'w-24 rounded-lg border border-border bg-surface px-2.5 py-1.5 text-right text-sm outline-none focus:border-accent';
@endphp

@section('content')
<div x-data="posScreen(@js($table), @js($session), @js($menu), @js($mergeTargets), @js($paymentMethods))">
    {{-- ---- No session: open the table ---- --}}
    <template x-if="!session">
        <div class="mx-auto max-w-md">
            <a href="/floor" class="inline-flex items-center gap-2 text-sm font-medium text-fg-muted hover:text-accent">
                <i data-lucide="arrow-left" class="h-4 w-4"></i> Back to floor
            </a>
            <div class="card mt-3 p-6">
                <h2 class="font-display text-xl font-semibold" x-text="'Open Table ' + table.number"></h2>
                <p class="mt-1 text-sm text-fg-muted">Seat guests to start a session.</p>
                <div class="mt-5 grid grid-cols-2 gap-3">
                    <label class="text-sm"><span class="mb-1 block text-xs text-fg-muted">Guests</span>
                        <input type="number" min="1" x-model.number="guests" class="{{ $input }}"></label>
                    <label class="text-sm"><span class="mb-1 block text-xs text-fg-muted">Waiter</span>
                        <select x-model="waiterId" class="{{ $input }}">
                            <option value="">— None —</option>
                            @foreach ($waiters as $w)
                                <option value="{{ $w['id'] }}">{{ $w['name'] }}</option>
                            @endforeach
                        </select></label>
                    <label class="col-span-2 text-sm"><span class="mb-1 block text-xs text-fg-muted">Customer (optional)</span>
                        <input x-model="custName" placeholder="Walk-in" class="{{ $input }}"></label>
                </div>
                <button type="button" :disabled="pending" @click="openTable()" x-text="pending ? 'Opening…' : 'Open & seat'"
                        class="mt-5 w-full rounded-lg bg-accent px-4 py-2.5 text-sm font-semibold text-white hover:bg-accent-deep disabled:opacity-60"></button>
            </div>
        </div>
    </template>

    {{-- ---- Active session ---- --}}
    <template x-if="session">
        <div class="space-y-4">
            <div class="flex items-center justify-between">
                <a href="/floor" class="inline-flex items-center gap-2 text-sm font-medium text-fg-muted hover:text-accent">
                    <i data-lucide="arrow-left" class="h-4 w-4"></i> Back to floor
                </a>
                <span class="text-sm text-fg-muted"
                      x-text="`Table ${table.number}${table.name ? ` · ${table.name}` : ''} · ${session.customerCount} guests${session.waiterName ? ` · ${session.waiterName}` : ''}`"></span>
            </div>

            <div class="grid gap-4 lg:grid-cols-[1fr_360px]">
                {{-- Menu picker --}}
                <div class="card p-4">
                    <div class="flex flex-wrap items-center gap-2">
                        <div class="relative">
                            <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                            <input x-model="query" placeholder="Search dishes…" class="w-48 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
                        </div>
                        <div class="flex flex-wrap gap-1.5">
                            <template x-for="c in cats" :key="c">
                                <button type="button" @click="cat = c" x-text="c" class="rounded-pill px-3 py-1 text-xs font-medium transition-colors"
                                        :class="cat === c ? 'bg-accent text-white' : 'border border-border text-fg-muted hover:border-accent/40'"></button>
                            </template>
                        </div>
                    </div>
                    <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3">
                        <template x-for="m in filtered" :key="m.id">
                            <button type="button" @click="add(m.id)" class="flex flex-col rounded-xl border border-border p-3 text-left transition-colors hover:border-accent/40">
                                <span class="line-clamp-2 text-sm font-medium" x-text="m.name"></span>
                                <span class="mt-auto pt-2 text-sm font-semibold text-accent" x-text="formatCurrency(m.price)"></span>
                                <span x-show="cart[m.id]" class="mt-1 text-xs text-fg-muted" x-text="'In cart: ' + cart[m.id]"></span>
                            </button>
                        </template>
                    </div>
                </div>

                {{-- Bill --}}
                <div class="space-y-4">
                    {{-- New items cart --}}
                    <div x-show="cartCount > 0" class="card p-4">
                        <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-fg-muted">New items</p>
                        <ul class="space-y-1.5 text-sm">
                            <template x-for="l in cartLines" :key="l.menuItemId">
                                <li class="flex items-center justify-between gap-2">
                                    <span class="min-w-0 truncate" x-text="l.name"></span>
                                    <span class="flex items-center gap-1.5">
                                        <button type="button" @click="sub(l.menuItemId)" class="grid h-6 w-6 place-items-center rounded border border-border">−</button>
                                        <span class="w-5 text-center" x-text="l.qty"></span>
                                        <button type="button" @click="add(l.menuItemId)" class="grid h-6 w-6 place-items-center rounded border border-border">+</button>
                                    </span>
                                </li>
                            </template>
                        </ul>
                        <button type="button" :disabled="pending" @click="sendToKitchen()"
                                class="mt-3 inline-flex w-full items-center justify-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent-deep disabled:opacity-60">
                            <i data-lucide="chef-hat" class="h-4 w-4"></i> <span x-text="'Send to kitchen · ' + formatCurrency(cartTotal)"></span>
                        </button>
                    </div>

                    {{-- Merge another table into this one --}}
                    <div x-show="mergeTargets.length > 0" class="card p-3">
                        <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-fg-muted">Merge table</p>
                        <div class="flex gap-2">
                            <select x-model="mergeId" class="flex-1 rounded-lg border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-accent">
                                <option value="">Select a table…</option>
                                <template x-for="m in mergeTargets" :key="m.sessionId"><option :value="m.sessionId" x-text="'Table ' + m.number"></option></template>
                            </select>
                            <button type="button" :disabled="pending || !mergeId" @click="doMerge()"
                                    class="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-2 text-sm font-semibold hover:bg-bg disabled:opacity-50">
                                <i data-lucide="combine" class="h-4 w-4"></i> Merge
                            </button>
                        </div>
                    </div>

                    {{-- Running bill --}}
                    <div class="card p-4">
                        <div class="flex items-center justify-between">
                            <p class="text-xs font-semibold uppercase tracking-wide text-fg-muted">Bill</p>
                            <button type="button" @click="printDoc('KOT', kotHtml(session.lines))" class="inline-flex items-center gap-1 text-xs text-fg-muted hover:text-accent">
                                <i data-lucide="printer" class="h-3.5 w-3.5"></i> KOT
                            </button>
                        </div>
                        <p x-show="session.lines.length === 0" class="mt-3 text-sm text-fg-muted">No items yet — add from the menu.</p>
                        <ul x-show="session.lines.length > 0" class="mt-3 space-y-1.5 text-sm">
                            <template x-for="l in session.lines" :key="l.menuItemId">
                                <li class="flex items-center justify-between gap-2">
                                    <span class="flex min-w-0 items-center gap-1.5">
                                        <button type="button" :disabled="pending" @click="line(l.menuItemId, -1)" class="grid h-5 w-5 place-items-center rounded border border-border text-fg-muted hover:border-danger hover:text-danger disabled:opacity-50">−</button>
                                        <span class="w-4 text-center text-xs font-medium" x-text="l.qty"></span>
                                        <button type="button" :disabled="pending" @click="line(l.menuItemId, 1)" class="grid h-5 w-5 place-items-center rounded border border-border text-fg-muted hover:border-accent hover:text-accent disabled:opacity-50">+</button>
                                        <span class="min-w-0 truncate" x-text="l.name"></span>
                                    </span>
                                    <span class="whitespace-nowrap text-fg-muted" x-text="formatCurrency(l.qty * l.price)"></span>
                                </li>
                            </template>
                        </ul>

                        <div class="mt-4 space-y-2 border-t border-border pt-3">
                            <div class="flex items-center justify-between text-sm"><span class="text-fg-muted">Subtotal</span><span class="font-medium" x-text="formatCurrency(session.subtotal)"></span></div>
                            @foreach ([['Discount', 'discount'], ['Tax', 'tax'], ['Service', 'service'], ['Tip', 'tip']] as [$lbl, $key])
                                <label class="flex items-center justify-between gap-3 text-sm">
                                    <span class="text-fg-muted">{{ $lbl }}</span>
                                    <span class="inline-flex items-center gap-1">
                                        <span class="text-fg-muted">$</span>
                                        <input type="number" min="0" step="0.01" x-model.number="{{ $key }}" class="{{ $adjInput }}">
                                    </span>
                                </label>
                            @endforeach
                            <button type="button" @click="saveBilling()" :disabled="pending" class="text-xs font-medium text-accent hover:text-accent-deep disabled:opacity-60">Save adjustments</button>
                            <div class="flex items-center justify-between border-t border-border pt-3">
                                <span class="text-sm font-semibold">Total</span>
                                <span class="font-display text-xl font-semibold" x-text="formatCurrency(previewTotal)"></span>
                            </div>
                            <template x-if="session.paid > 0">
                                <div class="space-y-2">
                                    <div class="flex items-center justify-between text-sm"><span class="text-fg-muted">Paid</span><span class="font-medium text-success" x-text="formatCurrency(session.paid)"></span></div>
                                    <div class="flex items-center justify-between text-sm"><span class="text-fg-muted">Remaining</span><span class="font-medium" x-text="formatCurrency(Math.max(0, previewTotal - session.paid))"></span></div>
                                </div>
                            </template>
                        </div>

                        {{-- Split / partial payment --}}
                        <div class="mt-3 rounded-lg border border-border p-3">
                            <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-fg-muted">Split / partial payment</p>
                            <ul x-show="session.payments.length > 0" class="mb-2 space-y-1 text-xs text-fg-muted">
                                <template x-for="(p, i) in session.payments" :key="i">
                                    <li class="flex justify-between"><span x-text="p.method"></span><span x-text="formatCurrency(p.amount)"></span></li>
                                </template>
                            </ul>
                            <div class="flex gap-2">
                                <input type="number" min="0" step="0.01" x-model="payAmount" placeholder="Amount" class="w-24 rounded-lg border border-border bg-surface px-2.5 py-1.5 text-sm outline-none focus:border-accent">
                                <select x-model="payMethod2" class="rounded-lg border border-border bg-surface px-2 py-1.5 text-sm outline-none focus:border-accent">
                                    <template x-for="m in PAYMENT_METHODS" :key="m"><option :value="m" x-text="m"></option></template>
                                </select>
                                <button type="button" :disabled="pending" @click="doAddPayment()" class="rounded-lg border border-border px-3 py-1.5 text-sm font-semibold hover:bg-bg disabled:opacity-60">Add</button>
                            </div>
                        </div>

                        <div class="mt-3 space-y-2">
                            <button type="button" @click="printInvoice()" class="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-border px-4 py-2 text-sm font-semibold hover:bg-bg">
                                <i data-lucide="receipt" class="h-4 w-4"></i> Print invoice
                            </button>
                            <div class="flex gap-2">
                                <select x-model="payMethod" class="rounded-lg border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-accent">
                                    <template x-for="m in PAYMENT_METHODS" :key="m"><option :value="m" x-text="m"></option></template>
                                </select>
                                <button type="button" @click="closeAndPay()" :disabled="pending"
                                        class="flex-1 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent-deep disabled:opacity-60"
                                        x-text="'Close & Pay' + (session.paid > 0 ? ` · ${formatCurrency(Math.max(0, previewTotal - session.paid))}` : '')"></button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </template>
</div>
@endsection

@push('scripts')
<script>
    document.addEventListener('alpine:init', () => {
        const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

        // PosScreen.tsx (open form + PosActive)
        Alpine.data('posScreen', (table, session, menu, mergeTargets, PAYMENT_METHODS) => ({
            table, session, menu, mergeTargets, PAYMENT_METHODS,
            pending: false,
            // open-table form
            guests: 2, waiterId: '', custName: '',
            // active session
            query: '', cat: 'All', cart: {},
            discount: 0, tax: 0, service: 0, tip: 0,
            payMethod: PAYMENT_METHODS[0], payMethod2: PAYMENT_METHODS[0],
            mergeId: '', payAmount: '',
            init() {
                if (this.session) this.seedBilling();
            },
            seedBilling() {
                this.discount = this.session.discount;
                this.tax = this.session.tax;
                this.service = this.session.serviceCharge;
                this.tip = this.session.tip;
            },
            get available() { return this.menu.filter((m) => m.available); },
            get cats() { return ['All', ...Array.from(new Set(this.available.map((m) => m.category)))]; },
            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.available.filter((m) => (this.cat === 'All' || m.category === this.cat) && (!q || m.name.toLowerCase().includes(q)));
            },
            get cartLines() {
                return this.available.filter((m) => this.cart[m.id]).map((m) => ({ menuItemId: m.id, name: m.name, qty: this.cart[m.id], price: m.price }));
            },
            get cartTotal() { return this.cartLines.reduce((s, l) => s + l.qty * l.price, 0); },
            get cartCount() { return this.cartLines.reduce((n, l) => n + l.qty, 0); },
            get previewTotal() {
                const b = this.billing();
                return Math.max(0, this.session.subtotal - b.discount + b.tax + b.serviceCharge + b.tip);
            },
            add(id) { this.cart = { ...this.cart, [id]: (this.cart[id] ?? 0) + 1 }; },
            sub(id) {
                const n = { ...this.cart };
                const q = (n[id] ?? 0) - 1;
                if (q <= 0) delete n[id]; else n[id] = q;
                this.cart = n;
            },
            apply(res) {
                const had = !!this.session;
                if (res.table) this.table = res.table;
                this.session = res.session ?? null;
                if (res.mergeTargets) this.mergeTargets = res.mergeTargets;
                if (!had && this.session) this.seedBilling();
            },
            // router.refresh(): reload the live session; errors are toasted.
            async run(url, method, body) {
                this.pending = true;
                try {
                    this.apply(await api(url, { method, body: { tableId: this.table.id, ...(body ?? {}) } }));
                } catch (e) {
                    toast(e.message, 'error');
                    try { this.apply(await api(`/pos/${this.table.id}/data`)); } catch { /* ignore */ }
                } finally {
                    this.pending = false;
                }
            },
            openTable() {
                return this.run(`/pos/${this.table.id}/open`, 'POST', { customerCount: this.guests, waiterId: this.waiterId || null, customerName: this.custName || null });
            },
            line(menuItemId, delta) {
                return delta === 1
                    ? this.run(`/pos/sessions/${this.session.id}/orders`, 'POST', { items: [{ menuItemId, qty: 1 }] })
                    : this.run(`/pos/sessions/${this.session.id}/decrement`, 'POST', { menuItemId });
            },
            doMerge() {
                if (!this.mergeId) return;
                const from = this.mergeId;
                this.mergeId = '';
                return this.run(`/pos/sessions/${this.session.id}/merge`, 'POST', { fromSessionId: from });
            },
            async doAddPayment() {
                const amt = Number(this.payAmount);
                if (!(amt > 0)) return;
                await this.run(`/pos/sessions/${this.session.id}/payments`, 'POST', { amount: amt, method: this.payMethod2 });
                this.payAmount = '';
            },
            async sendToKitchen() {
                if (!this.cartCount) return;
                const items = this.cartLines.map((l) => ({ menuItemId: l.menuItemId, qty: l.qty }));
                this.printDoc('KOT', this.kotHtml(this.cartLines));
                await this.run(`/pos/sessions/${this.session.id}/orders`, 'POST', { items });
                this.cart = {};
            },
            billing() {
                const n = (v) => Number(v) || 0;
                return { discount: n(this.discount), tax: n(this.tax), serviceCharge: n(this.service), tip: n(this.tip) };
            },
            saveBilling() {
                return this.run(`/pos/sessions/${this.session.id}/billing`, 'PATCH', this.billing());
            },
            async closeAndPay() {
                this.pending = true;
                try {
                    await api(`/pos/sessions/${this.session.id}/close`, { method: 'POST', body: { ...this.billing(), paymentMethod: this.payMethod } });
                } catch (e) {
                    toast(e.message, 'error');
                }
                window.location.href = '/floor';
            },
            printDoc(title, inner) {
                const w = window.open('', '_blank', 'width=400,height=680');
                if (!w) return;
                w.document.write(`<!doctype html><html><head><title>${title}</title><style>
                    body{font-family:'Courier New',monospace;font-size:13px;padding:16px;color:#000;width:320px;margin:0 auto}
                    h1{font-size:16px;text-align:center;margin:0 0 2px} .muted{color:#555;font-size:11px;text-align:center;margin:0 0 8px}
                    table{width:100%;border-collapse:collapse} td{padding:2px 0;vertical-align:top} .r{text-align:right;white-space:nowrap}
                    .sep{border-top:1px dashed #000;margin:8px 0} .row{display:flex;justify-content:space-between} .big{font-weight:bold;font-size:15px}
                </style></head><body>${inner}<script>window.onload=function(){window.focus();window.print()}<\/script></body></html>`);
                w.document.close();
            },
            kotHtml(lines) {
                const rows = lines.map((l) => `<tr><td>${l.qty} ×</td><td>${esc(l.name)}</td></tr>`).join('');
                return `<h1>KITCHEN ORDER</h1><p class="muted">Table ${esc(this.table.number)} · ${new Date().toLocaleTimeString()}</p>
                    <div class="sep"></div><table>${rows}</table>`;
            },
            printInvoice() {
                const s = this.session, b = this.billing();
                const rows = s.lines.map((l) => `<tr><td>${l.qty} × ${esc(l.name)}</td><td class="r">${formatCurrency(l.qty * l.price)}</td></tr>`).join('');
                this.printDoc('Invoice', `<h1>Go4Foodie</h1><p class="muted">Table ${esc(this.table.number)} · ${new Date().toLocaleString()}</p>
                    <div class="sep"></div><table>${rows}</table><div class="sep"></div>
                    <div class="row"><span>Subtotal</span><span>${formatCurrency(s.subtotal)}</span></div>
                    ${b.discount ? `<div class="row"><span>Discount</span><span>-${formatCurrency(b.discount)}</span></div>` : ''}
                    ${b.tax ? `<div class="row"><span>Tax</span><span>${formatCurrency(b.tax)}</span></div>` : ''}
                    ${b.serviceCharge ? `<div class="row"><span>Service</span><span>${formatCurrency(b.serviceCharge)}</span></div>` : ''}
                    ${b.tip ? `<div class="row"><span>Tip</span><span>${formatCurrency(b.tip)}</span></div>` : ''}
                    <div class="sep"></div><div class="row big"><span>TOTAL</span><span>${formatCurrency(this.previewTotal)}</span></div>`);
            },
        }));
    });
</script>
@endpush
