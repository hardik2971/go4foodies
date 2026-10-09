@extends('layouts.app')

@php
    // InventoryForm.tsx field/label classes
    $field = 'w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none transition-colors focus:border-accent';
    $label = 'mb-1.5 block text-sm font-medium';
@endphp

@section('content')
<x-biz.helpers />
<div x-data="inventoryManager(@js($items), @js($categories))" x-effect="filtered; bizIcons()" class="space-y-5">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <x-biz.stat label="Total Items" icon="package" x-text="items.length" />
        <x-biz.stat label="Low Stock" icon="triangle-alert" x-text="items.filter(i => stockStatus(i) === 'LOW').length" />
        <x-biz.stat label="Out of Stock" icon="circle-x" x-text="items.filter(i => stockStatus(i) === 'OUT').length" />
        <x-biz.stat label="Stock Value" icon="dollar-sign" x-text="bizMoney(items.reduce((s, i) => s + i.quantity * i.costPerUnit, 0))" />
    </div>

    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="f in ['All', ...categories]" :key="f">
                <button type="button" @click="filter = f"
                        class="rounded-pill px-3.5 py-1.5 text-sm font-medium transition-colors"
                        :class="filter === f ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"
                        x-text="f"></button>
            </template>
        </div>
        <div class="flex items-center gap-3">
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" placeholder="Search items…"
                       class="w-48 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
            </div>
            <button type="button" @click="openAdd()"
                    class="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep">
                <i data-lucide="plus" class="h-4 w-4"></i>
                Add Item
            </button>
        </div>
    </div>

    <div class="card overflow-x-auto">
        <table class="w-full text-sm">
            <thead>
            <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
                <th class="px-5 py-3 font-medium">Item</th>
                <th class="px-5 py-3 font-medium">Category</th>
                <th class="px-5 py-3 font-medium">Supplier</th>
                <th class="px-5 py-3 font-medium">Stock</th>
                <th class="px-5 py-3 font-medium">Status</th>
                <th class="px-5 py-3 text-right font-medium">Actions</th>
            </tr>
            </thead>
            <tbody>
            <template x-for="it in filtered" :key="it.id">
                <tr class="border-b border-border last:border-0 hover:bg-bg/60" :class="stockStatus(it) === 'OUT' && 'bg-danger-soft/30'">
                    <td class="px-5 py-3 font-medium" x-text="it.name"></td>
                    <td class="px-5 py-3 text-fg-muted" x-text="it.category"></td>
                    <td class="px-5 py-3 text-fg-muted" x-text="it.supplier || '—'"></td>
                    <td class="px-5 py-3">
                        <div class="flex items-center gap-2">
                            <button type="button" @click="adjust(it, -1)" aria-label="Decrease"
                                    class="grid h-6 w-6 place-items-center rounded-md border border-border text-fg-muted hover:border-accent/40">
                                <i data-lucide="minus" class="h-3 w-3"></i>
                            </button>
                            <span class="min-w-16 text-center font-medium tabular-nums" x-text="`${it.quantity} ${it.unit}`"></span>
                            <button type="button" @click="adjust(it, 1)" aria-label="Increase"
                                    class="grid h-6 w-6 place-items-center rounded-md border border-border text-fg-muted hover:border-accent/40">
                                <i data-lucide="plus" class="h-3 w-3"></i>
                            </button>
                        </div>
                        <span class="mt-0.5 block text-xs text-fg-muted" x-text="`reorder at ${it.reorderLevel}`"></span>
                    </td>
                    <td class="px-5 py-3">
                        <span class="rounded-md px-2 py-0.5 text-xs font-semibold" :class="META[stockStatus(it)].cls" x-text="META[stockStatus(it)].label"></span>
                    </td>
                    <td class="px-5 py-3">
                        <div class="flex items-center justify-end gap-1.5">
                            <button type="button" @click="openEdit(it)" aria-label="Edit"
                                    class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-accent-soft hover:text-accent">
                                <i data-lucide="pencil" class="h-4 w-4"></i>
                            </button>
                            <button type="button" @click="remove(it)" aria-label="Delete"
                                    class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-danger-soft hover:text-danger">
                                <i data-lucide="trash-2" class="h-4 w-4"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            </template>
            <tr x-show="filtered.length === 0" x-cloak>
                <td colspan="6" class="px-5 py-12 text-center text-sm text-fg-muted">No inventory items match your filters.</td>
            </tr>
            </tbody>
        </table>
    </div>

    <x-biz.modal show="modalOpen" close="modalOpen = false" title-expr="editing ? 'Edit inventory item' : 'Add inventory item'">
        <form @submit.prevent="submit()" class="space-y-4" novalidate>
            <div>
                <label class="{{ $label }}">Name</label>
                <input x-model="form.name" class="{{ $field }}" placeholder="Sea Bass (whole)">
                <p x-show="errors.name" x-text="errors.name" class="mt-1 text-xs text-danger"></p>
            </div>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Category</label>
                    <select x-model="form.category" class="{{ $field }} appearance-none">
                        @foreach ($categories as $c)
                            <option value="{{ $c }}">{{ $c }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    <label class="{{ $label }}">Unit</label>
                    <input x-model="form.unit" class="{{ $field }}" placeholder="kg, L, units">
                    <p x-show="errors.unit" x-text="errors.unit" class="mt-1 text-xs text-danger"></p>
                </div>
            </div>
            <div class="grid grid-cols-3 gap-4">
                <div>
                    <label class="{{ $label }}">Quantity</label>
                    <input type="number" step="0.01" x-model="form.quantity" class="{{ $field }}">
                </div>
                <div>
                    <label class="{{ $label }}">Reorder at</label>
                    <input type="number" step="0.01" x-model="form.reorderLevel" class="{{ $field }}">
                </div>
                <div>
                    <label class="{{ $label }}">Cost / unit</label>
                    <input type="number" step="0.01" x-model="form.costPerUnit" class="{{ $field }}">
                </div>
            </div>
            <p x-show="errors.numbers" x-text="errors.numbers" class="text-xs text-danger"></p>
            <div>
                <label class="{{ $label }}">Supplier</label>
                <input x-model="form.supplier" class="{{ $field }}" placeholder="Boston Seafood Co.">
            </div>
            <div class="flex justify-end gap-3 pt-2">
                <button type="button" @click="modalOpen = false"
                        class="rounded-lg border border-border px-4 py-2 text-sm font-medium transition-colors hover:bg-bg">Cancel</button>
                <button type="submit" :disabled="saving"
                        class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep disabled:opacity-60"
                        x-text="editing ? 'Save changes' : 'Add item'"></button>
            </div>
        </form>
    </x-biz.modal>
</div>
@endsection

@push('scripts')
<script>
    function inventoryManager(initial, categories) {
        const BLANK = { name: '', category: 'Dry Goods', unit: 'kg', quantity: 0, reorderLevel: 0, costPerUnit: 0, supplier: '' };
        const stockStatus = (i) => (i.quantity <= 0 ? 'OUT' : i.quantity <= i.reorderLevel ? 'LOW' : 'IN_STOCK');
        return {
            items: initial,
            categories,
            stockStatus,
            META: {
                IN_STOCK: { label: 'In Stock', cls: 'bg-success-soft text-success' },
                LOW: { label: 'Low Stock', cls: 'bg-warn-soft text-warn' },
                OUT: { label: 'Out of Stock', cls: 'bg-danger-soft text-danger' },
            },
            filter: 'All',
            query: '',
            modalOpen: false,
            editing: null,
            saving: false,
            form: { ...BLANK },
            errors: {},

            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.items.filter((it) =>
                    (this.filter === 'All' || it.category === this.filter) &&
                    (q === '' || it.name.toLowerCase().includes(q) || (it.supplier || '').toLowerCase().includes(q)));
            },
            async adjust(it, delta) {
                const prev = it.quantity;
                it.quantity = Math.max(0, it.quantity + delta);
                try { await api(`/inventory/${it.id}/adjust`, { method: 'PATCH', body: { delta } }); }
                catch (err) { it.quantity = prev; toast(err.message, 'error'); }
            },
            async remove(it) {
                if (!confirm('Remove this inventory item?')) return;
                const before = this.items;
                this.items = this.items.filter((x) => x.id !== it.id);
                try { await api(`/inventory/${it.id}`, { method: 'DELETE' }); }
                catch (err) { this.items = before; toast(err.message, 'error'); }
            },
            openAdd() {
                this.editing = null;
                this.form = { ...BLANK };
                this.errors = {};
                this.modalOpen = true;
            },
            openEdit(it) {
                this.editing = it;
                this.form = {
                    name: it.name, category: it.category, unit: it.unit, quantity: it.quantity,
                    reorderLevel: it.reorderLevel, costPerUnit: it.costPerUnit, supplier: it.supplier,
                };
                this.errors = {};
                this.modalOpen = true;
            },
            validate() {
                const f = this.form, errs = {};
                if (String(f.name).trim().length < 2) errs.name = 'Name is required';
                if (String(f.unit).trim().length < 1) errs.unit = 'Unit is required';
                for (const k of ['quantity', 'reorderLevel', 'costPerUnit']) {
                    const n = Number(f[k]);
                    if (f[k] === '' || isNaN(n) || n < 0) errs.numbers = 'Number must be greater than or equal to 0';
                }
                this.errors = errs;
                return Object.keys(errs).length === 0;
            },
            async submit() {
                if (!this.validate()) return;
                const values = {
                    ...this.form,
                    quantity: Number(this.form.quantity),
                    reorderLevel: Number(this.form.reorderLevel),
                    costPerUnit: Number(this.form.costPerUnit),
                };
                this.saving = true;
                try {
                    if (this.editing) {
                        await api(`/inventory/${this.editing.id}`, { method: 'PUT', body: values });
                        Object.assign(this.editing, values, { supplier: values.supplier ?? '' });
                    } else {
                        const res = await api('/inventory', { method: 'POST', body: values });
                        this.items = res.items;
                    }
                    this.modalOpen = false;
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
