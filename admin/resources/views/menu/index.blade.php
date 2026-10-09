@extends('layouts.app')

@php
    $field = 'w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none transition-colors focus:border-accent';
    $label = 'mb-1.5 block text-sm font-medium';
@endphp

@section('content')
<div class="space-y-5" x-data="menuManager(@js($items), @js($categories), @js($menuCategories))">
    {{-- Category visibility — disabled categories are hidden from the public site --}}
    <template x-if="categories.length > 0">
        <div class="card p-4">
            <div class="mb-3 flex items-center justify-between">
                <p class="text-xs font-semibold uppercase tracking-wide text-fg-muted">Categories</p>
                <p class="text-xs text-fg-muted">Disabled categories are hidden from the website menu</p>
            </div>
            <div class="flex flex-wrap gap-2">
                <template x-for="c in categories" :key="c.id">
                    <button type="button" @click="toggleCategory(c.id)" :title="c.active ? 'Click to hide from website' : 'Click to show on website'"
                            class="inline-flex items-center gap-1.5 rounded-pill border px-3 py-1.5 text-sm font-medium transition-colors"
                            :class="c.active ? 'border-success/40 bg-success-soft text-success' : 'border-border bg-bg text-fg-muted line-through'">
                        <span x-show="c.active" class="inline-flex"><i data-lucide="eye" class="h-3.5 w-3.5"></i></span>
                        <span x-show="!c.active" class="inline-flex"><i data-lucide="eye-off" class="h-3.5 w-3.5"></i></span>
                        <span x-text="c.name"></span>
                        <span class="not-italic no-underline opacity-70" x-text="'(' + c.itemCount + ')'"></span>
                    </button>
                </template>
            </div>
        </div>
    </template>

    {{-- Toolbar --}}
    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="f in ['All', ...MENU_CATEGORIES]" :key="f">
                <button type="button" @click="filter = f" x-text="f"
                        class="rounded-pill px-3.5 py-1.5 text-sm font-medium transition-colors"
                        :class="filter === f ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"></button>
            </template>
        </div>
        <div class="flex items-center gap-3">
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" placeholder="Search dishes…" class="w-48 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
            </div>
            <button type="button" @click="openAdd()" class="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep">
                <i data-lucide="plus" class="h-4 w-4"></i> Add Item
            </button>
        </div>
    </div>

    {{-- Table --}}
    <div class="card overflow-hidden">
        <table class="w-full text-sm">
            <thead>
                <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
                    <th class="px-5 py-3 font-medium">Item</th>
                    <th class="px-5 py-3 font-medium">Category</th>
                    <th class="px-5 py-3 font-medium">Price</th>
                    <th class="px-5 py-3 font-medium">Rating</th>
                    <th class="px-5 py-3 font-medium">Status</th>
                    <th class="px-5 py-3 text-right font-medium">Actions</th>
                </tr>
            </thead>
            <tbody>
                <tr x-show="filtered.length === 0">
                    <td colspan="6" class="px-5 py-12 text-center text-sm text-fg-muted">No dishes match your filters.</td>
                </tr>
                <template x-for="it in filtered" :key="it.id">
                    <tr class="border-b border-border last:border-0 hover:bg-bg/60">
                        <td class="px-5 py-3">
                            <div class="flex items-center gap-3">
                                <div class="relative h-11 w-11 shrink-0 overflow-hidden rounded-lg">
                                    <img :src="it.imageUrl" :alt="it.name" class="absolute inset-0 h-full w-full object-cover" loading="lazy">
                                </div>
                                <div class="min-w-0">
                                    <p class="font-medium" x-text="it.name"></p>
                                    <p class="truncate text-xs text-fg-muted" x-text="it.tag"></p>
                                </div>
                            </div>
                        </td>
                        <td class="px-5 py-3 text-fg-muted" x-text="it.category"></td>
                        <td class="px-5 py-3 font-medium" x-text="formatCurrency(it.price)"></td>
                        <td class="px-5 py-3">
                            <span class="inline-flex items-center gap-1"><i data-lucide="star" class="h-3.5 w-3.5 fill-gold text-gold"></i><span x-text="it.rating"></span></span>
                        </td>
                        <td class="px-5 py-3">
                            <button type="button" @click="toggleAvailable(it.id)" :aria-label="it.available ? 'Available' : 'Unavailable'"
                                    class="inline-flex h-5 w-9 items-center rounded-full p-0.5 transition-colors" :class="it.available ? 'bg-success' : 'bg-border'">
                                <span class="h-4 w-4 rounded-full bg-white shadow transition-transform" :class="it.available && 'translate-x-4'"></span>
                            </button>
                        </td>
                        <td class="px-5 py-3">
                            <div class="flex items-center justify-end gap-1.5">
                                <button type="button" @click="openEdit(it)" aria-label="Edit" class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-accent-soft hover:text-accent">
                                    <i data-lucide="pencil" class="h-4 w-4"></i>
                                </button>
                                <button type="button" @click="remove(it.id)" aria-label="Delete" class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-danger-soft hover:text-danger">
                                    <i data-lucide="trash-2" class="h-4 w-4"></i>
                                </button>
                            </div>
                        </td>
                    </tr>
                </template>
            </tbody>
        </table>
    </div>

    <p class="text-xs text-fg-muted">
        Showing <span x-text="filtered.length"></span> of <span x-text="items.length"></span> items. Changes are in-session until the MySQL
        data layer is connected.
    </p>

    {{-- Add / edit (MenuItemForm.tsx) --}}
    <x-ops.modal show="modalOpen" close="modalOpen = false" title-expr="editing ? 'Edit menu item' : 'Add menu item'">
        <form @submit.prevent="submit()" class="space-y-4" novalidate>
            <div>
                <label class="{{ $label }}">Name</label>
                <input x-model="form.name" class="{{ $field }}" placeholder="Truffle Risotto">
                <p x-show="errors.name" class="mt-1 text-xs text-danger" x-text="errors.name"></p>
            </div>
            <div>
                <label class="{{ $label }}">Description</label>
                <textarea x-model="form.description" rows="2" class="{{ $field }} resize-none" placeholder="Short description of the dish…"></textarea>
                <p x-show="errors.description" class="mt-1 text-xs text-danger" x-text="errors.description"></p>
            </div>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Category</label>
                    <select x-model="form.category" class="{{ $field }} appearance-none">
                        @foreach ($menuCategories as $c)
                            <option value="{{ $c }}">{{ $c }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    <label class="{{ $label }}">Tag</label>
                    <input x-model="form.tag" class="{{ $field }}" placeholder="Popular">
                </div>
            </div>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Price ($)</label>
                    <input type="number" step="0.01" x-model="form.price" class="{{ $field }}" placeholder="26">
                    <p x-show="errors.price" class="mt-1 text-xs text-danger" x-text="errors.price"></p>
                </div>
                <div>
                    <label class="{{ $label }}">Rating (0–5)</label>
                    <input type="number" step="0.1" x-model="form.rating" class="{{ $field }}" placeholder="4.8">
                    <p x-show="errors.rating" class="mt-1 text-xs text-danger" x-text="errors.rating"></p>
                </div>
            </div>
            <div>
                <label class="{{ $label }}">Image</label>
                <div class="flex gap-3">
                    <div class="grid h-16 w-16 flex-none place-items-center overflow-hidden rounded-lg border border-border bg-bg">
                        <img x-show="form.imageUrl" :src="form.imageUrl" alt="Preview" class="h-full w-full object-cover">
                        <span x-show="!form.imageUrl" class="text-[10px] text-fg-muted">No image</span>
                    </div>
                    <div class="min-w-0 flex-1">
                        <div class="flex gap-2">
                            <input x-model="form.imageUrl" class="{{ $field }}" placeholder="https://… or upload →">
                            <label class="inline-flex cursor-pointer items-center gap-1.5 whitespace-nowrap rounded-lg border border-border px-3 py-2 text-sm font-medium transition-colors hover:bg-bg"
                                   :class="uploading && 'pointer-events-none opacity-60'">
                                <span x-show="uploading" class="inline-flex"><i data-lucide="loader-2" class="h-4 w-4 animate-spin"></i></span>
                                <span x-show="!uploading" class="inline-flex"><i data-lucide="upload" class="h-4 w-4"></i></span>
                                <span x-text="uploading ? 'Uploading…' : 'Upload'"></span>
                                <input type="file" accept="image/*" @change="handleFile($event)" class="hidden">
                            </label>
                        </div>
                        <p class="mt-1 text-xs text-fg-muted">Paste an image URL or upload a file (max 5MB).</p>
                        <p x-show="uploadError" class="mt-1 text-xs text-danger" x-text="uploadError"></p>
                        <p x-show="errors.imageUrl" class="mt-1 text-xs text-danger" x-text="errors.imageUrl"></p>
                    </div>
                </div>
            </div>
            <label class="flex items-center gap-2 text-sm">
                <input type="checkbox" x-model="form.available" class="h-4 w-4 accent-[var(--color-accent)]">
                Available on menu
            </label>
            <div class="flex justify-end gap-3 pt-2">
                <button type="button" @click="modalOpen = false" class="rounded-lg border border-border px-4 py-2 text-sm font-medium transition-colors hover:bg-bg">Cancel</button>
                <button type="submit" class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep" x-text="editing ? 'Save changes' : 'Add item'"></button>
            </div>
        </form>
    </x-ops.modal>
</div>
@endsection

@push('scripts')
<script>
    document.addEventListener('alpine:init', () => {
        const BLANK = {
            name: '', description: '', price: 0, rating: 0, tag: '', category: 'Main Meals',
            imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=70',
            available: true,
        };
        const isUrl = (s) => { try { new URL(s); return true; } catch { return false; } };

        // MenuManager.tsx + MenuItemForm.tsx
        Alpine.data('menuManager', (initialItems, initialCategories, MENU_CATEGORIES) => ({
            items: initialItems,
            categories: initialCategories,
            MENU_CATEGORIES,
            filter: 'All',
            query: '',
            modalOpen: false,
            editing: null,
            form: { ...BLANK },
            errors: {},
            uploading: false,
            uploadError: '',
            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.items.filter((it) =>
                    (this.filter === 'All' || it.category === this.filter) &&
                    (q === '' || it.name.toLowerCase().includes(q) || (it.tag ?? '').toLowerCase().includes(q)));
            },
            toggleCategory(id) {
                const cat = this.categories.find((c) => c.id === id);
                if (!cat) return;
                const next = !cat.active;
                this.categories = this.categories.map((c) => (c.id === id ? { ...c, active: next } : c));
                api(`/menu/categories/${id}/active`, { method: 'PATCH', body: { active: next } }).catch((e) => toast(e.message, 'error'));
            },
            openAdd() {
                this.editing = null;
                this.form = { ...BLANK };
                this.errors = {};
                this.uploadError = '';
                this.modalOpen = true;
            },
            openEdit(item) {
                this.editing = item;
                this.form = {
                    name: item.name, description: item.description, price: item.price, rating: item.rating,
                    tag: item.tag, category: item.category, imageUrl: item.imageUrl, available: item.available,
                };
                this.errors = {};
                this.uploadError = '';
                this.modalOpen = true;
            },
            toggleAvailable(id) {
                const item = this.items.find((it) => it.id === id);
                if (!item) return;
                const next = !item.available;
                this.items = this.items.map((it) => (it.id === id ? { ...it, available: next } : it));
                api(`/menu/items/${id}/availability`, { method: 'PATCH', body: { available: next } }).catch((e) => toast(e.message, 'error'));
            },
            remove(id) {
                if (!confirm('Remove this item from the menu?')) return;
                this.items = this.items.filter((it) => it.id !== id);
                api(`/menu/items/${id}`, { method: 'DELETE' }).catch((e) => toast(e.message, 'error'));
            },
            async handleFile(e) {
                const file = e.target.files?.[0];
                e.target.value = '';
                if (!file) return;
                this.uploading = true;
                this.uploadError = '';
                try {
                    const fd = new FormData();
                    fd.append('file', file);
                    const res = await fetch('/api/upload', {
                        method: 'POST',
                        body: fd,
                        headers: { Accept: 'application/json', 'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content ?? '' },
                    });
                    const data = await res.json().catch(() => ({}));
                    if (!res.ok) throw new Error(data.error || 'Upload failed');
                    this.form.imageUrl = data.url;
                    delete this.errors.imageUrl;
                } catch (err) {
                    this.uploadError = err instanceof Error ? err.message : 'Upload failed';
                } finally {
                    this.uploading = false;
                }
            },
            // menuItemSchema (zod)
            validate() {
                const f = this.form, e = {};
                if (String(f.name ?? '').length < 2) e.name = 'Name is required';
                if (String(f.description ?? '').length < 4) e.description = 'Add a short description';
                const price = Number(f.price);
                if (f.price === '' || Number.isNaN(price) || price < 0) e.price = 'Price must be positive';
                const rating = Number(f.rating === '' ? 0 : f.rating);
                if (Number.isNaN(rating) || rating < 0) e.rating = 'Number must be greater than or equal to 0';
                else if (rating > 5) e.rating = 'Number must be less than or equal to 5';
                if (!isUrl(f.imageUrl)) e.imageUrl = 'Enter a valid image URL';
                this.errors = e;
                return Object.keys(e).length === 0;
            },
            async submit() {
                if (!this.validate()) return;
                const values = { ...this.form, price: Number(this.form.price), rating: Number(this.form.rating || 0), tag: this.form.tag ?? '' };
                if (this.editing) {
                    const id = this.editing.id;
                    this.items = this.items.map((it) => (it.id === id ? { ...it, ...values } : it));
                    this.modalOpen = false;
                    api(`/menu/items/${id}`, { method: 'PUT', body: values }).catch((e) => toast(e.message, 'error'));
                } else {
                    this.items = [{ id: `tmp-${Date.now()}`, ...values }, ...this.items];
                    this.modalOpen = false;
                    try {
                        const res = await api('/menu/items', { method: 'POST', body: values });
                        if (res.items) this.items = res.items;
                        if (res.categories) this.categories = res.categories;
                    } catch (e) {
                        toast(e.message, 'error');
                    }
                }
            },
        }));
    });
</script>
@endpush
