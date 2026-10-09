@extends('layouts.app')

@php
    // CustomerForm.tsx field/label classes
    $field = 'w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none transition-colors focus:border-accent';
    $label = 'mb-1.5 block text-sm font-medium';
@endphp

@section('content')
<x-biz.helpers />
<div x-data="customersManager(@js($customers))" x-effect="filtered; bizIcons()" class="space-y-5">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <x-biz.stat label="Total Customers" icon="users" x-text="stats.total" />
        <x-biz.stat label="Lifetime Value" icon="dollar-sign" x-text="bizMoney(stats.lifetime)" />
        <x-biz.stat label="Avg Spend" icon="trending-up" x-text="bizMoney(stats.avg)" />
        <x-biz.stat label="Repeat Guests" icon="repeat" x-text="stats.repeat" />
    </div>

    {{-- Toolbar --}}
    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="s in ['ALL', 'ACTIVE', 'INACTIVE']" :key="s">
                <button type="button" @click="statusFilter = s"
                        class="rounded-pill px-3.5 py-1.5 text-sm font-medium transition-colors"
                        :class="statusFilter === s ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"
                        x-text="s === 'ALL' ? 'All' : s === 'ACTIVE' ? 'Active' : 'Inactive'"></button>
            </template>
        </div>

        <div class="flex items-center gap-3">
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" placeholder="Search customers…"
                       class="w-52 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
            </div>
            <button type="button" @click="openAdd()"
                    class="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep">
                <i data-lucide="plus" class="h-4 w-4"></i>
                Add Customer
            </button>
        </div>
    </div>

    <div class="card overflow-x-auto">
        <table class="w-full text-sm">
            <thead>
            <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
                <th class="px-5 py-3 font-medium">Customer</th>
                <th class="px-5 py-3 font-medium">Phone</th>
                <th class="px-5 py-3 font-medium">Address</th>
                <th class="px-5 py-3 font-medium">Status</th>
                <th class="px-5 py-3 font-medium">Created</th>
                <th class="px-5 py-3 text-right font-medium">Actions</th>
            </tr>
            </thead>
            <tbody>
            <template x-for="(c, i) in filtered" :key="c.id">
                <tr class="border-b border-border last:border-0 hover:bg-bg/60">
                    <td class="px-5 py-3">
                        <div class="flex items-center gap-3">
                            <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full text-xs font-semibold text-white"
                                  :class="BIZ_AVATAR_COLORS[i % BIZ_AVATAR_COLORS.length]" x-text="bizInitials(c.name)"></span>
                            <div class="min-w-0">
                                <p class="font-medium" x-text="c.name"></p>
                                <p class="truncate text-xs text-fg-muted" x-text="c.email"></p>
                            </div>
                        </div>
                    </td>
                    <td class="px-5 py-3 text-fg-muted" x-text="c.phone ?? '—'"></td>
                    <td class="px-5 py-3 text-fg-muted">
                        <span class="line-clamp-1 max-w-[16rem]" x-text="c.address || '—'"></span>
                    </td>
                    <td class="px-5 py-3">
                        <span class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold"
                              :class="c.status === 'ACTIVE' ? 'bg-success-soft text-success' : 'bg-bg text-fg-muted'">
                            <span class="h-1.5 w-1.5 rounded-full bg-current"></span>
                            <span x-text="c.status === 'ACTIVE' ? 'Active' : 'Inactive'"></span>
                        </span>
                    </td>
                    <td class="px-5 py-3 text-fg-muted" x-text="c.createdAt ? bizDate(c.createdAt, 'MMM d, yyyy') : '—'"></td>
                    <td class="px-5 py-3">
                        <div class="flex items-center justify-end gap-1.5">
                            <button type="button" @click="view = c; viewIndex = i" aria-label="View"
                                    class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-accent-soft hover:text-accent">
                                <i data-lucide="eye" class="h-4 w-4"></i>
                            </button>
                            <button type="button" @click="openEdit(c)" aria-label="Edit"
                                    class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-accent-soft hover:text-accent">
                                <i data-lucide="pencil" class="h-4 w-4"></i>
                            </button>
                            <button type="button" @click="remove(c)" aria-label="Delete"
                                    class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-danger-soft hover:text-danger">
                                <i data-lucide="trash-2" class="h-4 w-4"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            </template>
            <tr x-show="filtered.length === 0" x-cloak>
                <td colspan="6" class="px-5 py-12 text-center text-sm text-fg-muted">No customers match your filters.</td>
            </tr>
            </tbody>
        </table>
    </div>

    {{-- Add / Edit --}}
    <x-biz.modal show="formOpen" close="formOpen = false" title-expr="editing ? 'Edit customer' : 'Add customer'">
        <form @submit.prevent="submit()" class="space-y-4" novalidate>
            <div>
                <label class="{{ $label }}">Name</label>
                <input x-model="form.name" class="{{ $field }}" placeholder="Jane Doe">
                <p x-show="errors.name" x-text="errors.name" class="mt-1 text-xs text-danger"></p>
            </div>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Email</label>
                    <input x-model="form.email" class="{{ $field }}" placeholder="jane@email.com">
                    <p x-show="errors.email" x-text="errors.email" class="mt-1 text-xs text-danger"></p>
                </div>
                <div>
                    <label class="{{ $label }}">Phone</label>
                    <input x-model="form.phone" class="{{ $field }}" placeholder="+1 555 000 0000">
                </div>
            </div>
            <div>
                <label class="{{ $label }}">Address</label>
                <input x-model="form.address" class="{{ $field }}" placeholder="Street, City, State">
            </div>
            <div>
                <label class="{{ $label }}">Status</label>
                <select x-model="form.status" class="{{ $field }} appearance-none">
                    <option value="ACTIVE">Active</option>
                    <option value="INACTIVE">Inactive</option>
                </select>
            </div>
            <div class="flex justify-end gap-3 pt-2">
                <button type="button" @click="formOpen = false"
                        class="rounded-lg border border-border px-4 py-2 text-sm font-medium transition-colors hover:bg-bg">Cancel</button>
                <button type="submit" :disabled="saving"
                        class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep disabled:opacity-60"
                        x-text="editing ? 'Save changes' : 'Add customer'"></button>
            </div>
        </form>
    </x-biz.modal>

    {{-- View / history --}}
    <x-biz.modal show="!!view" close="view = null" title="Customer">
        <template x-if="view">
            <div class="space-y-5" x-init="bizIcons()">
                <div class="flex items-center gap-4">
                    <span class="grid h-12 w-12 shrink-0 place-items-center rounded-full text-base font-semibold text-white"
                          :class="BIZ_AVATAR_COLORS[viewIndex % BIZ_AVATAR_COLORS.length]" x-text="bizInitials(view.name)"></span>
                    <div class="min-w-0">
                        <div class="flex items-center gap-2">
                            <p class="font-display text-lg font-semibold" x-text="view.name"></p>
                            <span class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold"
                                  :class="view.status === 'ACTIVE' ? 'bg-success-soft text-success' : 'bg-bg text-fg-muted'">
                                <span class="h-1.5 w-1.5 rounded-full bg-current"></span>
                                <span x-text="view.status === 'ACTIVE' ? 'Active' : 'Inactive'"></span>
                            </span>
                        </div>
                        <div class="mt-1 flex flex-col gap-0.5 text-sm text-fg-muted">
                            <a :href="`mailto:${view.email}`" class="inline-flex items-center gap-2 hover:text-accent">
                                <i data-lucide="mail" class="h-3.5 w-3.5"></i> <span x-text="view.email"></span>
                            </a>
                            <a x-show="view.phone" :href="`tel:${view.phone}`" class="inline-flex items-center gap-2 hover:text-accent">
                                <i data-lucide="phone" class="h-3.5 w-3.5"></i> <span x-text="view.phone"></span>
                            </a>
                            <span x-show="view.address" class="inline-flex items-center gap-2">
                                <i data-lucide="map-pin" class="h-3.5 w-3.5"></i> <span x-text="view.address"></span>
                            </span>
                        </div>
                    </div>
                </div>

                <div class="grid grid-cols-3 gap-3 text-center">
                    <div class="rounded-lg bg-bg px-3 py-3">
                        <p class="text-xs text-fg-muted">Lifetime</p>
                        <p class="mt-0.5 font-display text-lg font-semibold" x-text="bizMoney(view.totalSpend)"></p>
                    </div>
                    <div class="rounded-lg bg-bg px-3 py-3">
                        <p class="text-xs text-fg-muted">Orders</p>
                        <p class="mt-0.5 font-display text-lg font-semibold" x-text="view.orders.length"></p>
                    </div>
                    <div class="rounded-lg bg-bg px-3 py-3">
                        <p class="text-xs text-fg-muted">Visits</p>
                        <p class="mt-0.5 font-display text-lg font-semibold" x-text="visits(view)"></p>
                    </div>
                </div>

                <div x-show="view.orders.length > 0">
                    <p class="mb-2 text-xs uppercase tracking-wide text-fg-muted">Order history</p>
                    <ul class="divide-y divide-border rounded-xl border border-border">
                        <template x-for="o in view.orders" :key="o.number">
                            <li class="flex items-center justify-between px-4 py-2.5 text-sm">
                                <span class="font-medium" x-text="o.number"></span>
                                <span class="text-fg-muted" x-text="bizDate(o.date, 'MMM d')"></span>
                                <span class="font-medium" x-text="bizMoney(o.total)"></span>
                            </li>
                        </template>
                    </ul>
                </div>

                <div x-show="view.reservations.length > 0">
                    <p class="mb-2 text-xs uppercase tracking-wide text-fg-muted">Reservations</p>
                    <ul class="divide-y divide-border rounded-xl border border-border">
                        <template x-for="r in view.reservations" :key="r.reference">
                            <li class="flex items-center justify-between px-4 py-2.5 text-sm">
                                <span class="font-medium" x-text="r.reference"></span>
                                <span class="text-fg-muted" x-text="bizDate(r.date, 'MMM d')"></span>
                                <span class="text-fg-muted" x-text="r.kind === 'TABLE' ? 'Table' : 'Event'"></span>
                            </li>
                        </template>
                    </ul>
                </div>
            </div>
        </template>
    </x-biz.modal>
</div>
@endsection

@push('scripts')
<script>
    function customersManager(initial) {
        const BLANK = { name: '', email: '', phone: '', address: '', status: 'ACTIVE' };
        const visits = (c) => c.orders.length + c.reservations.length;
        return {
            customers: initial,
            query: '',
            statusFilter: 'ALL',
            view: null,
            viewIndex: 0,
            formOpen: false,
            editing: null,
            saving: false,
            form: { ...BLANK },
            errors: {},
            visits,

            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.customers.filter((c) =>
                    (this.statusFilter === 'ALL' || c.status === this.statusFilter) &&
                    (q === '' ||
                        c.name.toLowerCase().includes(q) ||
                        c.email.toLowerCase().includes(q) ||
                        (c.phone ?? '').toLowerCase().includes(q)));
            },
            get stats() {
                const lifetime = this.customers.reduce((s, c) => s + c.totalSpend, 0);
                const repeat = this.customers.filter((c) => visits(c) > 1).length;
                const avg = this.customers.length ? Math.round(lifetime / this.customers.length) : 0;
                return { total: this.customers.length, lifetime, repeat, avg };
            },

            openAdd() {
                this.editing = null;
                this.form = { ...BLANK };
                this.errors = {};
                this.formOpen = true;
            },
            openEdit(c) {
                this.editing = c;
                this.form = { name: c.name, email: c.email, phone: c.phone ?? '', address: c.address ?? '', status: c.status };
                this.errors = {};
                this.formOpen = true;
            },
            async remove(c) {
                if (!confirm(`Delete customer "${c.name}"?`)) return;
                const before = this.customers;
                this.customers = this.customers.filter((x) => x.id !== c.id);
                try { await api(`/customers/${c.id}`, { method: 'DELETE' }); }
                catch (err) { this.customers = before; toast(err.message, 'error'); }
            },
            validate() {
                const f = this.form, errs = {};
                if (f.name.trim().length < 2) errs.name = 'Name is required';
                if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email)) errs.email = 'Enter a valid email';
                this.errors = errs;
                return Object.keys(errs).length === 0;
            },
            async submit() {
                if (!this.validate()) return;
                const values = { ...this.form };
                this.saving = true;
                try {
                    if (this.editing) {
                        await api(`/customers/${this.editing.id}`, { method: 'PUT', body: values });
                        Object.assign(this.editing, values, { phone: values.phone || undefined, address: values.address || undefined });
                    } else {
                        const res = await api('/customers', { method: 'POST', body: values });
                        this.customers = res.customers;
                    }
                    this.formOpen = false;
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
