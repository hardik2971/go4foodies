@extends('layouts.app')

@php
    $fieldClass = 'w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-accent';
@endphp

@section('content')
<div class="space-y-5" x-data="reservationsManager(@js($reservations))">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        @foreach ([['Total', 'stats.total', 'calendar-clock'], ['New Requests', 'stats.requested', 'users'], ['Confirmed', 'stats.confirmed', 'circle-check'], ['Private Events', 'stats.events', 'party-popper']] as [$label, $expr, $icon])
            <div class="card flex items-center gap-3 p-4">
                <span class="grid h-10 w-10 place-items-center rounded-lg bg-accent-soft text-accent"><i data-lucide="{{ $icon }}" class="h-5 w-5"></i></span>
                <div>
                    <p class="text-xs text-fg-muted">{{ $label }}</p>
                    <p class="font-display text-xl font-semibold" x-text="{{ $expr }}"></p>
                </div>
            </div>
        @endforeach
    </div>

    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="s in STATUS_FILTERS" :key="s">
                <button type="button" @click="status = s" x-text="s === 'ALL' ? 'All' : STATUS_LABELS[s]"
                        class="rounded-pill px-3.5 py-1.5 text-sm font-medium transition-colors"
                        :class="status === s ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"></button>
            </template>
        </div>
        <div class="flex flex-wrap items-center gap-3">
            <input type="date" x-model="date" aria-label="Filter by date"
                   class="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg-muted outline-none focus:border-accent">
            <button type="button" x-show="date" @click="date = ''" class="text-xs font-medium text-fg-muted hover:text-accent">Clear date</button>
            <select x-model="kind" class="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg-muted outline-none focus:border-accent">
                <option value="ALL">All kinds</option>
                <option value="TABLE">Table Booking</option>
                <option value="PRIVATE_EVENT">Private Event</option>
            </select>
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" placeholder="Search ref, name, email…" class="w-56 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
            </div>
        </div>
    </div>

    <div class="card overflow-x-auto">
        <table class="w-full text-sm">
            <thead>
                <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
                    <th class="px-5 py-3 font-medium">Reference</th>
                    <th class="px-5 py-3 font-medium">Guest</th>
                    <th class="px-5 py-3 font-medium">Kind</th>
                    <th class="px-5 py-3 font-medium">Date</th>
                    <th class="px-5 py-3 font-medium">Party</th>
                    <th class="px-5 py-3 font-medium">Status</th>
                    <th class="px-5 py-3 text-right font-medium">View</th>
                </tr>
            </thead>
            <tbody>
                <tr x-show="filtered.length === 0">
                    <td colspan="7" class="px-5 py-12 text-center text-sm text-fg-muted">No reservations match your filters.</td>
                </tr>
                <template x-for="r in filtered" :key="r.id">
                    <tr class="cursor-pointer border-b border-border last:border-0 hover:bg-bg/60" @click="open(r)">
                        <td class="px-5 py-3 font-medium">
                            <span class="flex items-center gap-2.5">
                                <span class="grid h-8 w-8 flex-none place-items-center rounded-lg bg-accent-soft text-accent" :title="KIND_LABELS[r.kind]">
                                    <span x-show="r.kind === 'TABLE'" class="inline-flex"><i data-lucide="utensils" class="h-4 w-4"></i></span>
                                    <span x-show="r.kind !== 'TABLE'" class="inline-flex"><i data-lucide="party-popper" class="h-4 w-4"></i></span>
                                </span>
                                <span x-text="r.reference"></span>
                            </span>
                        </td>
                        <td class="px-5 py-3">
                            <p x-text="r.name"></p>
                            <p class="text-xs text-fg-muted" x-text="r.email"></p>
                        </td>
                        <td class="px-5 py-3 text-fg-muted" x-text="KIND_LABELS[r.kind]"></td>
                        <td class="px-5 py-3">
                            <span class="inline-flex items-center gap-1.5">
                                <i data-lucide="calendar-clock" class="h-3.5 w-3.5 text-fg-muted"></i>
                                <span x-text="fmtDate(r.date, 'MMM d')"></span>
                                <span x-show="r.time" class="text-fg-muted" x-text="'· ' + r.time"></span>
                            </span>
                        </td>
                        <td class="px-5 py-3 text-fg-muted">
                            <span class="inline-flex items-center gap-1.5">
                                <i data-lucide="users" class="h-3.5 w-3.5"></i>
                                <span x-text="r.kind === 'TABLE' ? `${r.guests} guests` : r.guestRange"></span>
                            </span>
                        </td>
                        <td class="px-5 py-3">
                            <span class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold" :class="STATUS_STYLES[r.status]">
                                <span class="h-1.5 w-1.5 rounded-full bg-current"></span><span x-text="STATUS_LABELS[r.status]"></span>
                            </span>
                        </td>
                        <td class="px-5 py-3">
                            <div class="flex justify-end"><span class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted"><i data-lucide="eye" class="h-4 w-4"></i></span></div>
                        </td>
                    </tr>
                </template>
            </tbody>
        </table>
    </div>

    <p class="text-xs text-fg-muted">
        Showing <span x-text="filtered.length"></span> of <span x-text="items.length"></span> reservations. Once MySQL is live, bookings
        submitted on the public site land here automatically.
    </p>

    {{-- ReservationDetail.tsx --}}
    <x-ops.modal show="active" close="active = null" title-expr="active?.reference">
        <template x-if="active">
            <div class="space-y-5">
                <div class="flex items-center justify-between">
                    <span class="rounded-full bg-accent-soft px-2.5 py-1 text-xs font-semibold text-accent" x-text="KIND_LABELS[active.kind]"></span>
                    <span class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold" :class="STATUS_STYLES[active.status]">
                        <span class="h-1.5 w-1.5 rounded-full bg-current"></span><span x-text="STATUS_LABELS[active.status]"></span>
                    </span>
                </div>

                {{-- Step-wise status progress --}}
                <div class="rounded-xl border border-border px-4 py-4">
                    <ol class="flex items-start">
                        <template x-for="(s, i) in flow()" :key="s">
                            <li class="flex flex-1 items-start last:flex-none">
                                <div class="flex flex-col items-center gap-1.5">
                                    <span class="grid h-8 w-8 place-items-center rounded-full border text-xs font-semibold transition-colors"
                                          :class="step(i) === 'current' ? 'border-accent bg-accent text-white ring-4 ring-accent-soft' : (step(i) === 'done' ? 'border-accent bg-accent text-white' : 'border-border bg-surface text-fg-muted')">
                                        <span x-show="step(i) === 'done'"><i data-lucide="check" class="h-4 w-4"></i></span>
                                        <span x-show="step(i) !== 'done'" x-text="i + 1"></span>
                                    </span>
                                    <span class="text-center text-[11px] font-medium leading-tight" :class="step(i) !== 'todo' ? 'text-fg' : 'text-fg-muted'" x-text="STATUS_LABELS[s]"></span>
                                </div>
                                <template x-if="i < flow().length - 1">
                                    <span class="mx-1 mt-4 h-0.5 flex-1 rounded transition-colors" :class="i < flowIndex() ? 'bg-accent' : 'bg-border'"></span>
                                </template>
                            </li>
                        </template>
                    </ol>
                    <template x-if="isOff()">
                        <div class="mt-3 flex items-center gap-2 rounded-lg border border-danger/40 bg-danger-soft px-3 py-2 text-sm font-medium text-danger">
                            <i data-lucide="x" class="h-4 w-4"></i> <span x-text="'This reservation was ' + STATUS_LABELS[active.status].toLowerCase() + '.'"></span>
                        </div>
                    </template>
                </div>

                {{-- Contact --}}
                <div class="rounded-xl border border-border p-4">
                    <p class="font-display text-base font-semibold" x-text="active.name"></p>
                    <div class="mt-2 flex flex-col gap-1.5 text-sm text-fg-muted">
                        <a :href="'mailto:' + active.email" class="inline-flex items-center gap-2 hover:text-accent"><i data-lucide="mail" class="h-4 w-4"></i> <span x-text="active.email"></span></a>
                        <a :href="'tel:' + active.phone" class="inline-flex items-center gap-2 hover:text-accent"><i data-lucide="phone" class="h-4 w-4"></i> <span x-text="active.phone"></span></a>
                    </div>
                </div>

                {{-- Details — edit form (table bookings) --}}
                <template x-if="editing && active.kind === 'TABLE'">
                    <div class="space-y-3 rounded-xl border border-border p-4">
                        <div class="grid grid-cols-2 gap-3">
                            <label class="text-sm"><span class="mb-1 block text-xs text-fg-muted">Date</span>
                                <input type="date" x-model="draft.date" class="{{ $fieldClass }}"></label>
                            <label class="text-sm"><span class="mb-1 block text-xs text-fg-muted">Time</span>
                                <input type="time" x-model="draft.time" class="{{ $fieldClass }}"></label>
                            <label class="text-sm"><span class="mb-1 block text-xs text-fg-muted">Guests</span>
                                <input type="number" min="1" x-model.number="draft.guests" class="{{ $fieldClass }}"></label>
                            <label class="text-sm"><span class="mb-1 block text-xs text-fg-muted">Occasion</span>
                                <input x-model="draft.occasion" class="{{ $fieldClass }}"></label>
                        </div>
                        <label class="block text-sm"><span class="mb-1 block text-xs text-fg-muted">Notes / requests</span>
                            <textarea rows="2" x-model="draft.requests" class="{{ $fieldClass }} resize-none"></textarea></label>
                        <div class="flex justify-end gap-2">
                            <button type="button" @click="editing = false" class="rounded-lg border border-border px-4 py-2 text-sm font-semibold hover:bg-bg">Cancel</button>
                            <button type="button" @click="save()" class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent-deep">Save changes</button>
                        </div>
                    </div>
                </template>

                {{-- Details — read --}}
                <template x-if="!(editing && active.kind === 'TABLE')">
                    <dl class="divide-y divide-border rounded-xl border border-border px-4">
                        <template x-for="[label, value] in detailRows()" :key="label">
                            <div class="flex items-center justify-between gap-6 py-2.5 text-sm">
                                <dt class="text-fg-muted" x-text="label"></dt>
                                <dd class="text-right font-medium" x-text="value"></dd>
                            </div>
                        </template>
                    </dl>
                </template>

                {{-- Edit toggle — table bookings that aren't closed out --}}
                <template x-if="active.kind === 'TABLE' && !editing && !isClosed()">
                    <button type="button" @click="startEdit()" class="inline-flex items-center gap-2 text-sm font-semibold text-accent hover:text-accent-deep">
                        <i data-lucide="pencil" class="h-4 w-4"></i> Edit reservation
                    </button>
                </template>

                {{-- Workflow --}}
                <template x-if="!editing && nextStatuses().length > 0">
                    <div>
                        <p class="mb-2 text-xs uppercase tracking-wide text-fg-muted">Update status</p>
                        <div class="flex flex-wrap gap-2">
                            <template x-for="s in nextStatuses()" :key="s">
                                <button type="button" @click="changeStatus(active.id, s)" x-text="'Mark ' + STATUS_LABELS[s]"
                                        class="rounded-lg px-4 py-2 text-sm font-semibold transition-colors"
                                        :class="s === 'CANCELED' || s === 'NO_SHOW' ? 'border border-danger/40 text-danger hover:bg-danger-soft' : 'bg-accent text-white hover:bg-accent-deep'"></button>
                            </template>
                        </div>
                    </div>
                </template>
                <template x-if="!editing && nextStatuses().length === 0">
                    <p class="text-sm text-fg-muted" x-text="'This reservation is ' + STATUS_LABELS[active.status] + ' — no further actions.'"></p>
                </template>
            </div>
        </template>
    </x-ops.modal>
</div>
@endsection

@push('scripts')
<script>
    document.addEventListener('alpine:init', () => {
        const FLOWS = { TABLE: ['REQUESTED', 'CONFIRMED', 'SEATED', 'COMPLETED'], PRIVATE_EVENT: ['REQUESTED', 'CONFIRMED', 'COMPLETED'] };
        const KIND_LABELS = { TABLE: 'Table Booking', PRIVATE_EVENT: 'Private Event' };
        const STATUS_LABELS = { REQUESTED: 'Pending', CONFIRMED: 'Confirmed', SEATED: 'Checked In', COMPLETED: 'Completed', CANCELED: 'Cancelled', NO_SHOW: 'No-show' };
        const STATUS_STYLES = {
            REQUESTED: 'bg-warn-soft text-warn', CONFIRMED: 'bg-info-soft text-info', SEATED: 'bg-accent-soft text-accent',
            COMPLETED: 'bg-success-soft text-success', CANCELED: 'bg-danger-soft text-danger', NO_SHOW: 'bg-bg text-fg-muted',
        };

        // ReservationsManager.tsx + ReservationDetail.tsx
        Alpine.data('reservationsManager', (initial) => ({
            items: initial,
            status: 'ALL',
            kind: 'ALL',
            date: '',
            query: '',
            active: null,
            editing: false,
            draft: {},
            STATUS_FILTERS: ['ALL', 'REQUESTED', 'CONFIRMED', 'SEATED', 'COMPLETED', 'CANCELED', 'NO_SHOW'],
            KIND_LABELS, STATUS_LABELS, STATUS_STYLES,
            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.items.filter((r) =>
                    (this.status === 'ALL' || r.status === this.status) &&
                    (this.kind === 'ALL' || r.kind === this.kind) &&
                    (this.date === '' || r.date.slice(0, 10) === this.date) &&
                    (q === '' || r.reference.toLowerCase().includes(q) || r.name.toLowerCase().includes(q) || r.email.toLowerCase().includes(q)));
            },
            get stats() {
                return {
                    total: this.items.length,
                    requested: this.items.filter((r) => r.status === 'REQUESTED').length,
                    confirmed: this.items.filter((r) => r.status === 'CONFIRMED' || r.status === 'SEATED').length,
                    events: this.items.filter((r) => r.kind === 'PRIVATE_EVENT').length,
                };
            },
            open(r) {
                this.editing = false;
                this.active = r;
            },
            flow() { return FLOWS[this.active.kind]; },
            isOff() { return this.active.status === 'CANCELED' || this.active.status === 'NO_SHOW'; },
            isClosed() { return ['COMPLETED', 'CANCELED', 'NO_SHOW'].includes(this.active.status); },
            flowIndex() { return this.isOff() ? -1 : this.flow().indexOf(this.active.status); },
            step(i) {
                const cur = this.flowIndex();
                if (cur < 0) return 'todo';
                return i < cur ? 'done' : i === cur ? 'current' : 'todo';
            },
            nextStatuses() {
                const { kind, status } = this.active;
                if (this.isClosed()) return [];
                const flow = FLOWS[kind];
                const idx = flow.indexOf(status);
                const forward = idx >= 0 && idx < flow.length - 1 ? [flow[idx + 1]] : [];
                return [...forward, ...(kind === 'TABLE' ? ['CANCELED', 'NO_SHOW'] : ['CANCELED'])];
            },
            detailRows() {
                const r = this.active;
                const rows = [['Date', fmtDate(r.date, 'EEE, MMM d, yyyy')]];
                const more = r.kind === 'TABLE'
                    ? [['Time', r.time], ['Guests', r.guests], ['Occasion', r.occasion], ['Requests', r.requests]]
                    : [['Event type', r.eventType], ['Estimated guests', r.guestRange], ['Space', r.space], ['Company', r.company], ['Details', r.message]];
                return [...rows, ...more].filter(([, v]) => v !== undefined && v !== null && v !== '');
            },
            startEdit() {
                const r = this.active;
                this.draft = { date: r.date.slice(0, 10), time: r.time ?? '', guests: r.guests, occasion: r.occasion ?? '', requests: r.requests ?? '' };
                this.editing = true;
            },
            save() {
                const id = this.active.id, patch = { ...this.draft };
                const apply = (r) => ({
                    ...r,
                    ...(patch.date ? { date: patch.date } : {}),
                    time: patch.time, guests: patch.guests, occasion: patch.occasion, requests: patch.requests,
                });
                this.items = this.items.map((r) => (r.id === id ? apply(r) : r));
                this.active = { ...this.active, ...patch };
                this.editing = false;
                api(`/reservations/${id}`, { method: 'PATCH', body: patch }).catch((e) => toast(e.message, 'error'));
            },
            changeStatus(id, next) {
                this.items = this.items.map((r) => (r.id === id ? { ...r, status: next } : r));
                if (this.active && this.active.id === id) this.active = { ...this.active, status: next };
                api(`/reservations/${id}/status`, { method: 'PATCH', body: { status: next } }).catch((e) => toast(e.message, 'error'));
            },
        }));
    });
</script>
@endpush
