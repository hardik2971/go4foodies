@extends('layouts.app')

@php
    $input = 'w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-accent';
@endphp

@section('content')
<div class="space-y-5" x-data="floorPlan(@js($tables), @js($states), @js($paymentMethods))">
    {{-- Live stats --}}
    <div class="card flex flex-wrap items-center gap-x-8 gap-y-3 p-4">
        @foreach ([['total', 'Total', 'text-fg'], ['AVAILABLE', 'Available', 'text-success'], ['OCCUPIED', 'Occupied', 'text-danger'], ['RESERVED', 'Reserved', 'text-warn'], ['WAITING_PAYMENT', 'Awaiting Pay', 'text-[#b45309]'], ['CLEANING', 'Cleaning', 'text-info'], ['OUT_OF_SERVICE', 'Out of Service', 'text-fg-muted']] as [$key, $label, $tone])
            <div>
                <p class="font-display text-2xl font-semibold {{ $tone }}" x-text="counts[@js($key)] ?? 0"></p>
                <p class="text-xs text-fg-muted">{{ $label }}</p>
            </div>
        @endforeach
        <button type="button" @click="refresh()"
                class="ml-auto inline-flex items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm font-medium text-fg-muted transition-colors hover:border-accent/40 hover:text-accent">
            <i data-lucide="refresh-cw" class="h-4 w-4"></i> Refresh
        </button>
    </div>

    {{-- Grid --}}
    <div x-show="tables.length === 0" class="card px-5 py-16 text-center text-sm text-fg-muted">No tables yet — add tables in Table Management.</div>
    <div x-show="tables.length > 0" class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
        <template x-for="t in tables" :key="t.id">
            <button type="button" @click="select(t)" class="rounded-xl border p-4 text-left transition-transform hover:-translate-y-0.5" :class="UI[t.state].card">
                <div class="flex items-start justify-between">
                    <div>
                        <p class="font-display text-lg font-semibold" x-text="'Table ' + t.number"></p>
                        <p x-show="t.name" class="text-xs text-fg-muted" x-text="t.name"></p>
                    </div>
                    <span class="rounded-md px-2 py-0.5 text-[10px] font-semibold" :class="UI[t.state].badge" x-text="UI[t.state].label"></span>
                </div>
                <div x-show="t.session" class="mt-3 space-y-1 text-xs text-fg-muted">
                    <p class="flex items-center gap-1.5"><i data-lucide="users" class="h-3.5 w-3.5"></i> <span x-text="t.session ? `${t.session.customerCount} guests${t.session.waiterName ? ` · ${t.session.waiterName}` : ''}` : ''"></span></p>
                    <p class="flex items-center gap-1.5"><i data-lucide="clock" class="h-3.5 w-3.5"></i> <span x-text="t.session ? `${fmtDuration(t.session.openedAt)} · ${t.session.orderCount} orders` : ''"></span></p>
                    <p class="flex items-center gap-1.5 font-semibold text-fg"><i data-lucide="receipt" class="h-3.5 w-3.5"></i> <span x-text="t.session ? formatCurrency(t.session.currentBill) : ''"></span></p>
                </div>
                <p x-show="!t.session" class="mt-3 text-xs text-fg-muted" x-text="'Seats ' + t.capacity"></p>
            </button>
        </template>
    </div>

    {{-- Detail / actions --}}
    <x-ops.modal show="active" close="active = null" title-expr="active ? `Table ${active.number}` : ''">
        <template x-if="active">
            <div class="space-y-5">
                <div class="flex items-center justify-between">
                    <span class="rounded-md px-2.5 py-1 text-xs font-semibold" :class="UI[active.state].badge" x-text="UI[active.state].label"></span>
                    <span x-show="active.name" class="text-sm text-fg-muted" x-text="`${active.name} · seats ${active.capacity}`"></span>
                </div>

                <div class="flex gap-2">
                    <a :href="`/pos/${active.id}`" class="inline-flex flex-1 items-center justify-center gap-2 rounded-lg bg-accent px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-accent-deep">
                        <i data-lucide="receipt" class="h-4 w-4"></i> <span x-text="'Open POS ' + (active.session ? `· ${formatCurrency(active.session.currentBill)}` : '')"></span>
                    </a>
                    <a :href="`/table-history/${active.id}`" class="rounded-lg border border-border px-4 py-2.5 text-sm font-semibold transition-colors hover:bg-bg">History</a>
                </div>

                <template x-if="active.session">
                    <div class="space-y-5">
                        <dl class="grid grid-cols-2 gap-3 text-sm">
                            <template x-for="[k, v] in sessionRows()" :key="k">
                                <div class="rounded-lg border border-border px-3 py-2">
                                    <dt class="text-xs text-fg-muted" x-text="k"></dt>
                                    <dd class="mt-0.5 font-medium" x-text="v"></dd>
                                </div>
                            </template>
                        </dl>
                        <div class="rounded-xl border border-border p-4">
                            <p class="mb-2 text-xs uppercase tracking-wide text-fg-muted">Close &amp; pay</p>
                            <div class="flex flex-wrap items-center gap-2">
                                <select x-model="payMethod" class="rounded-lg border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-accent">
                                    <template x-for="m in PAYMENT_METHODS" :key="m"><option :value="m" x-text="m"></option></template>
                                </select>
                                <button type="button" :disabled="pending" @click="doClose(active)" x-text="`Close table · ${formatCurrency(active.session.currentBill)}`"
                                        class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent-deep disabled:opacity-60"></button>
                                <button type="button" x-show="active.state !== 'WAITING_PAYMENT'" @click="doState(active, 'WAITING_PAYMENT')"
                                        class="rounded-lg border border-border px-4 py-2 text-sm font-semibold hover:bg-bg">Awaiting payment</button>
                            </div>
                        </div>
                    </div>
                </template>

                <template x-if="!active.session">
                    <div class="rounded-xl border border-border p-4">
                        <p class="mb-3 text-xs uppercase tracking-wide text-fg-muted">Open table</p>
                        <div class="grid grid-cols-2 gap-3">
                            <label class="text-sm"><span class="mb-1 block text-xs text-fg-muted">Guests</span>
                                <input type="number" min="1" x-model.number="guests" class="{{ $input }}"></label>
                            <label class="text-sm"><span class="mb-1 block text-xs text-fg-muted">Waiter</span>
                                <select x-model="waiterId" class="{{ $input }}">
                                    <option value="">— None —</option>
                                    @foreach ($waiters as $w)
                                        <option value="{{ $w['id'] }}">{{ $w['name'] }}</option>
                                    @endforeach
                                </select></label>
                            <label class="col-span-2 text-sm"><span class="mb-1 block text-xs text-fg-muted">Customer name (optional)</span>
                                <input x-model="custName" class="{{ $input }}" placeholder="Walk-in"></label>
                        </div>
                        <button type="button" :disabled="pending" @click="doOpen(active)"
                                class="mt-3 inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent-deep disabled:opacity-60">
                            <i data-lucide="user-round" class="h-4 w-4"></i> Open &amp; seat
                        </button>
                    </div>
                </template>

                {{-- State quick-set --}}
                <div>
                    <p class="mb-2 text-xs uppercase tracking-wide text-fg-muted">Set state</p>
                    <div class="flex flex-wrap gap-2">
                        <template x-for="s in STATES.filter((s) => s !== active.state)" :key="s">
                            <button type="button" @click="doState(active, s)" x-text="UI[s].label"
                                    :disabled="!!active.session && (s === 'AVAILABLE' || s === 'OUT_OF_SERVICE')"
                                    :title="active.session && (s === 'AVAILABLE' || s === 'OUT_OF_SERVICE') ? 'Close the open session first' : null"
                                    class="rounded-lg border px-3 py-1.5 text-xs font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-40"
                                    :class="UI[s].badge"></button>
                        </template>
                    </div>
                </div>
            </div>
        </template>
    </x-ops.modal>
</div>
@endsection

@push('scripts')
<script>
    document.addEventListener('alpine:init', () => {
        // floor-data.ts STATE_UI
        const UI = {
            AVAILABLE: { label: 'Available', card: 'border-success/40 bg-success-soft/50', badge: 'bg-success-soft text-success' },
            RESERVED: { label: 'Reserved', card: 'border-warn/40 bg-warn-soft/50', badge: 'bg-warn-soft text-warn' },
            OCCUPIED: { label: 'Occupied', card: 'border-danger/40 bg-danger-soft/50', badge: 'bg-danger-soft text-danger' },
            WAITING_PAYMENT: { label: 'Waiting Payment', card: 'border-accent/50 bg-accent-soft/60', badge: 'bg-accent-soft text-accent' },
            CLEANING: { label: 'Cleaning', card: 'border-info/40 bg-info-soft', badge: 'bg-info-soft text-info' },
            OUT_OF_SERVICE: { label: 'Out of Service', card: 'border-border bg-bg', badge: 'bg-bg text-fg-muted' },
        };

        // FloorPlan.tsx
        Alpine.data('floorPlan', (initial, STATES, PAYMENT_METHODS) => ({
            tables: initial,
            active: null,
            now: Date.now(),
            pending: false,
            guests: 2,
            waiterId: '',
            custName: '',
            payMethod: PAYMENT_METHODS[0],
            UI, STATES, PAYMENT_METHODS,
            init() {
                // Real-time: the Next page listens to the /api/floor-stream SSE. Here we poll a
                // cheap change token every 5s instead (a held-open SSE request would block
                // `php artisan serve`'s single worker) and refresh only when it changes;
                // the slow interval is kept as a safety net, like the Next page.
                setInterval(() => (this.now = Date.now()), 30_000);
                let version = null;
                const poll = async () => {
                    if (document.hidden) return;
                    try {
                        const { v } = await api('/floor/version');
                        if (version !== null && v !== version) this.refresh();
                        version = v;
                    } catch { /* offline — try again next tick */ }
                };
                poll();
                setInterval(poll, 5_000);
                setInterval(() => this.refresh(), 60_000);
            },
            get counts() {
                const c = { total: this.tables.length };
                for (const s of STATES) c[s] = 0;
                for (const t of this.tables) c[t.state] += 1;
                return c;
            },
            fmtDuration(fromIso) {
                const mins = Math.max(0, Math.floor((this.now - new Date(fromIso).getTime()) / 60000));
                const h = Math.floor(mins / 60);
                const m = mins % 60;
                return h > 0 ? `${h}h ${m}m` : `${m}m`;
            },
            select(t) {
                this.active = t;
            },
            sessionRows() {
                const s = this.active.session;
                return [
                    ['Guests', String(s.customerCount)],
                    ['Waiter', s.waiterName ?? '—'],
                    ['Duration', this.fmtDuration(s.openedAt)],
                    ['Orders', String(s.orderCount)],
                    ['Customer', s.customerName ?? '—'],
                    ['Current bill', formatCurrency(s.currentBill)],
                ];
            },
            setTables(tables) {
                this.tables = tables;
                // keep the open modal in sync (like useEffect(setTables, [initialTables]))
                if (this.active) this.active = tables.find((t) => t.id === this.active.id) ?? this.active;
            },
            async refresh() {
                try {
                    const res = await api('/floor/data');
                    this.setTables(res.tables);
                } catch { /* keep current view */ }
            },
            async doOpen(t) {
                this.pending = true;
                try {
                    await api(`/floor/tables/${t.id}/open`, { method: 'POST', body: { customerCount: this.guests, waiterId: this.waiterId || null, customerName: this.custName || null } });
                } catch (e) { toast(e.message, 'error'); }
                await this.refresh();
                this.active = null;
                this.pending = false;
            },
            async doClose(t) {
                if (!t.session) return;
                this.pending = true;
                try {
                    await api(`/floor/sessions/${t.session.id}/close`, { method: 'POST', body: { paymentMethod: this.payMethod } });
                } catch (e) { toast(e.message, 'error'); }
                await this.refresh();
                this.active = null;
                this.pending = false;
            },
            doState(t, state) {
                this.tables = this.tables.map((x) => (x.id === t.id ? { ...x, state } : x));
                if (this.active && this.active.id === t.id) this.active = { ...this.active, state };
                api(`/floor/tables/${t.id}/state`, { method: 'PATCH', body: { state } }).catch((e) => toast(e.message, 'error'));
            },
        }));
    });
</script>
@endpush
