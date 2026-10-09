@extends('layouts.app')

@php
    $field = 'w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none transition-colors focus:border-accent';
    $label = 'mb-1.5 block text-sm font-medium';
    $iconBtn = 'grid h-8 w-8 place-items-center rounded-lg text-fg-muted hover:bg-accent-soft hover:text-accent';
@endphp

@section('content')
<div class="space-y-5" x-data="tablesManager(@js($tables), @js($websiteUrl))">
    {{-- Toolbar --}}
    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="s in ['ALL', 'ACTIVE', 'INACTIVE']" :key="s">
                <button type="button" @click="statusFilter = s" x-text="s === 'ALL' ? 'All' : LABELS[s]"
                        class="rounded-pill px-3.5 py-1.5 text-sm font-medium transition-colors"
                        :class="statusFilter === s ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"></button>
            </template>
        </div>
        <div class="flex items-center gap-3">
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" placeholder="Search tables…" class="w-48 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
            </div>
            <button type="button" @click="openAdd()" class="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep">
                <i data-lucide="plus" class="h-4 w-4"></i> Add Table
            </button>
        </div>
    </div>

    {{-- Cards --}}
    <div x-show="filtered.length === 0" class="card px-5 py-16 text-center text-sm text-fg-muted">No tables match your filters.</div>
    <div x-show="filtered.length > 0" class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
        <template x-for="t in filtered" :key="t.id">
            <div class="card flex flex-col p-4">
                <div class="flex items-start justify-between">
                    <div>
                        <p class="font-display text-lg font-semibold" x-text="'Table ' + t.number"></p>
                        <p x-show="t.name" class="text-xs text-fg-muted" x-text="t.name"></p>
                    </div>
                    <button type="button" @click="toggleStatus(t)" :title="t.status === 'ACTIVE' ? 'Click to deactivate' : 'Click to activate'" x-text="LABELS[t.status]"
                            class="rounded-md px-2 py-0.5 text-xs font-semibold transition-colors"
                            :class="t.status === 'ACTIVE' ? 'bg-success-soft text-success' : 'bg-bg text-fg-muted'"></button>
                </div>
                <button type="button" @click="qrTable = t" title="View QR code"
                        class="mt-3 grid place-items-center rounded-lg border border-border bg-white p-3 transition-colors hover:border-accent/40">
                    <img x-effect="qr(t.code, 160).then((s) => $el.src = s)" :alt="`Table ${t.number} QR`" class="h-28 w-28">
                </button>
                <p class="mt-2 text-center text-[11px] text-fg-muted" x-text="t.orderCount + ' orders'"></p>
                <div class="mt-3 flex items-center justify-center gap-1.5 border-t border-border pt-3">
                    <button type="button" @click="qrTable = t" aria-label="QR" title="QR" class="{{ $iconBtn }}"><i data-lucide="qr-code" class="h-4 w-4"></i></button>
                    <button type="button" @click="downloadQR(t)" aria-label="Download" title="Download" class="{{ $iconBtn }}"><i data-lucide="download" class="h-4 w-4"></i></button>
                    <button type="button" @click="printQR(t)" aria-label="Print" title="Print" class="{{ $iconBtn }}"><i data-lucide="printer" class="h-4 w-4"></i></button>
                    <span class="mx-1 h-4 w-px bg-border"></span>
                    <button type="button" @click="openEdit(t)" aria-label="Edit" title="Edit" class="{{ $iconBtn }}"><i data-lucide="pencil" class="h-4 w-4"></i></button>
                    <button type="button" @click="remove(t)" aria-label="Delete" title="Delete" class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted hover:bg-danger-soft hover:text-danger"><i data-lucide="trash-2" class="h-4 w-4"></i></button>
                </div>
            </div>
        </template>
    </div>

    {{-- Add / Edit (TableForm.tsx) --}}
    <x-ops.modal show="formOpen" close="formOpen = false" title-expr="editing ? 'Edit table' : 'Add table'">
        <form @submit.prevent="submit()" class="space-y-4" novalidate>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Table number</label>
                    <input x-model="form.number" class="{{ $field }}" placeholder="12">
                    <p x-show="error" class="mt-1 text-xs text-danger" x-text="error"></p>
                </div>
                <div>
                    <label class="{{ $label }}">Table name</label>
                    <input x-model="form.name" class="{{ $field }}" placeholder="Window / Patio">
                </div>
            </div>
            <div>
                <label class="{{ $label }}">Status</label>
                <select x-model="form.status" class="{{ $field }} appearance-none">
                    <option value="ACTIVE">Active</option>
                    <option value="INACTIVE">Inactive</option>
                </select>
                <p class="mt-1 text-xs text-fg-muted">Inactive tables stop accepting QR orders.</p>
            </div>
            <div class="flex justify-end gap-3 pt-2">
                <button type="button" @click="formOpen = false" class="rounded-lg border border-border px-4 py-2 text-sm font-medium transition-colors hover:bg-bg">Cancel</button>
                <button type="submit" class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep" x-text="editing ? 'Save changes' : 'Add table'"></button>
            </div>
        </form>
    </x-ops.modal>

    {{-- QR detail --}}
    <x-ops.modal show="qrTable" close="qrTable = null" title-expr="qrTable ? `Table ${qrTable.number} · QR code` : ''">
        <template x-if="qrTable">
            <div class="space-y-4 text-center">
                <div class="mx-auto grid w-fit place-items-center rounded-xl border border-border bg-white p-5">
                    <img x-effect="qr(qrTable.code, 260).then((s) => $el.src = s)" :alt="`Table ${qrTable.number} QR`" class="h-56 w-56">
                </div>
                <a :href="tableUrl(qrTable.code)" target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-1.5 break-all text-xs text-accent hover:underline">
                    <i data-lucide="external-link" class="h-3.5 w-3.5 shrink-0"></i> <span x-text="tableUrl(qrTable.code)"></span>
                </a>
                <div class="flex justify-center gap-3 pt-1">
                    <button type="button" @click="downloadQR(qrTable)" class="inline-flex items-center gap-2 rounded-lg border border-border px-4 py-2 text-sm font-medium hover:bg-bg">
                        <i data-lucide="download" class="h-4 w-4"></i> Download
                    </button>
                    <button type="button" @click="printQR(qrTable)" class="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent-deep">
                        <i data-lucide="printer" class="h-4 w-4"></i> Print
                    </button>
                </div>
            </div>
        </template>
    </x-ops.modal>
</div>
@endsection

@push('scripts')
<script>
    document.addEventListener('alpine:init', () => {
        const BLANK = { number: '', name: '', status: 'ACTIVE' };
        const cache = new Map();

        // TablesManager.tsx — QR codes rendered client-side with the `qrcode` package.
        Alpine.data('tablesManager', (initial, websiteUrl) => ({
            tables: initial,
            query: '',
            statusFilter: 'ALL',
            formOpen: false,
            editing: null,
            qrTable: null,
            form: { ...BLANK },
            error: '',
            LABELS: { ACTIVE: 'Active', INACTIVE: 'Inactive' },
            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.tables.filter((t) =>
                    (this.statusFilter === 'ALL' || t.status === this.statusFilter) &&
                    (q === '' || t.number.toLowerCase().includes(q) || (t.name ?? '').toLowerCase().includes(q)));
            },
            tableUrl(code) {
                return `${websiteUrl}/order?table=${encodeURIComponent(code)}`;
            },
            qr(code, size) {
                const key = `${code}|${size}`;
                if (!cache.has(key)) {
                    cache.set(key, new Promise((resolve) => setTimeout(resolve)).then(() =>
                        window.QRCode.toDataURL(this.tableUrl(code), { width: size, margin: 1, errorCorrectionLevel: 'M' })));
                }
                return cache.get(key);
            },
            async downloadQR(t) {
                try {
                    const url = await this.qr(t.code, 600);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = `table-${t.number}-qr.png`;
                    document.body.appendChild(a);
                    a.click();
                    a.remove();
                } catch { /* ignore */ }
            },
            async printQR(t) {
                const w = window.open('', '_blank', 'width=420,height=620');
                if (!w) return;
                const src = await this.qr(t.code, 300);
                w.document.write(`<!doctype html><html><head><title>Table ${t.number} · QR</title>
                    <style>body{font-family:system-ui,sans-serif;text-align:center;padding:32px;color:#0a1c18}
                    h1{font-size:18px;letter-spacing:.18em;text-transform:uppercase;margin:0 0 4px}
                    p{color:#6b6b6b;margin:4px 0 20px}img{width:300px;height:300px}</style></head>
                    <body><h1>Go4Foodie</h1>
                    <p>Scan to order &middot; Table ${t.number}${t.name ? ' &middot; ' + t.name : ''}</p>
                    <img src="${src}" onload="window.focus();window.print();" alt="QR" />
                    </body></html>`);
                w.document.close();
            },
            openAdd() {
                this.editing = null;
                this.form = { ...BLANK };
                this.error = '';
                this.formOpen = true;
            },
            openEdit(t) {
                this.editing = t;
                this.form = { number: t.number, name: t.name ?? '', status: t.status };
                this.error = '';
                this.formOpen = true;
            },
            toggleStatus(t) {
                const next = t.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
                this.tables = this.tables.map((x) => (x.id === t.id ? { ...x, status: next } : x));
                api(`/tables/${t.id}/status`, { method: 'PATCH', body: { status: next } }).catch((e) => toast(e.message, 'error'));
            },
            remove(t) {
                if (!confirm(`Delete table ${t.number}? Its QR code will stop working.`)) return;
                this.tables = this.tables.filter((x) => x.id !== t.id);
                api(`/tables/${t.id}`, { method: 'DELETE' }).catch((e) => toast(e.message, 'error'));
            },
            async submit() {
                if (!String(this.form.number).trim()) { this.error = 'Table number is required'; return; }
                const values = { ...this.form };
                if (this.editing) {
                    const id = this.editing.id;
                    this.tables = this.tables.map((t) => (t.id === id ? { ...t, number: values.number, name: values.name || undefined, status: values.status } : t));
                    this.formOpen = false;
                    api(`/tables/${id}`, { method: 'PUT', body: values }).catch((e) => toast(e.message, 'error'));
                } else {
                    try {
                        const res = await api('/tables', { method: 'POST', body: values });
                        if (res.table) this.tables = [res.table, ...this.tables];
                    } catch (e) {
                        toast(e.message, 'error');
                    }
                    this.formOpen = false;
                }
            },
        }));
    });
</script>
@endpush
