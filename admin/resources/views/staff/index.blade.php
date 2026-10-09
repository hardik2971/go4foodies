@extends('layouts.app')

@php
    // StaffForm.tsx field/label classes
    $field = 'w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none transition-colors focus:border-accent';
    $label = 'mb-1.5 block text-sm font-medium';
@endphp

@section('content')
<x-biz.helpers />
<div x-data="staffManager(@js($employees), @js($roles))" x-effect="pageRows; bizIcons()" class="space-y-5">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <x-biz.stat label="Total Staff" icon="users" x-text="employees.length" />
        <x-biz.stat label="Active" icon="user-check" x-text="employees.filter(e => e.active).length" />
        <x-biz.stat label="On Duty" icon="coffee" x-text="employees.filter(e => e.status === 'ON_DUTY').length" />
        <x-biz.stat label="Inactive" icon="user-x" x-text="employees.filter(e => !e.active).length" />
    </div>

    <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap gap-2">
            <template x-for="s in ['ALL', 'ON_DUTY', 'ON_BREAK', 'ABSENT', 'OFF']" :key="s">
                <button type="button" @click="status = s; page = 0"
                        class="rounded-pill px-3.5 py-1.5 text-sm font-medium transition-colors"
                        :class="status === s ? 'bg-accent text-white' : 'border border-border bg-surface text-fg-muted hover:border-accent/40'"
                        x-text="s === 'ALL' ? 'All duty' : LABELS[s]"></button>
            </template>
        </div>

        <div class="flex flex-wrap items-center gap-3">
            <select x-model="activeFilter" @change="page = 0"
                    class="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg-muted outline-none focus:border-accent">
                <option value="ALL">All accounts</option>
                <option value="ACTIVE">Active</option>
                <option value="INACTIVE">Inactive</option>
            </select>
            <select x-model="role" @change="page = 0"
                    class="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg-muted outline-none focus:border-accent">
                <option value="ALL">All roles</option>
                <template x-for="r in roleOptions" :key="r"><option :value="r" x-text="r"></option></template>
            </select>
            <div class="relative">
                <i data-lucide="search" class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-muted"></i>
                <input x-model="query" @input="page = 0" placeholder="Search staff…"
                       class="w-44 rounded-lg border border-border bg-surface py-2 pl-9 pr-3 text-sm outline-none focus:border-accent">
            </div>
            <button type="button" @click="openAdd()"
                    class="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep">
                <i data-lucide="plus" class="h-4 w-4"></i>
                Add Staff
            </button>
        </div>
    </div>

    <div class="card overflow-x-auto">
        <table class="w-full text-sm">
            <thead>
            <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
                <th class="px-5 py-3 font-medium">Staff</th>
                <th class="px-5 py-3 font-medium">Phone</th>
                <th class="px-5 py-3 font-medium">Role</th>
                <th class="px-5 py-3 font-medium">Status</th>
                <th class="px-5 py-3 font-medium">Duty</th>
                <th class="px-5 py-3 text-right font-medium">Actions</th>
            </tr>
            </thead>
            <tbody>
            <template x-for="(e, i) in pageRows" :key="e.id">
                <tr class="border-b border-border last:border-0 hover:bg-bg/60">
                    <td class="px-5 py-3">
                        <div class="flex items-center gap-3">
                            <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full text-xs font-semibold text-white"
                                  :class="BIZ_AVATAR_COLORS[i % BIZ_AVATAR_COLORS.length]" x-text="bizInitials(e.name)"></span>
                            <div class="min-w-0">
                                <p class="font-medium" x-text="e.name"></p>
                                <p class="truncate text-xs text-fg-muted" x-text="e.email"></p>
                            </div>
                        </div>
                    </td>
                    <td class="px-5 py-3 text-fg-muted" x-text="e.phone ?? '—'"></td>
                    <td class="px-5 py-3 text-fg-muted" x-text="e.role"></td>
                    <td class="px-5 py-3">
                        <button type="button" @click="toggleActive(e)" :title="e.active ? 'Click to deactivate' : 'Click to activate'"
                                class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold transition-colors"
                                :class="e.active ? 'bg-success-soft text-success' : 'bg-bg text-fg-muted'">
                            <span class="h-1.5 w-1.5 rounded-full bg-current"></span>
                            <span x-text="e.active ? 'Active' : 'Inactive'"></span>
                        </button>
                    </td>
                    <td class="px-5 py-3">
                        <select @change="setDuty(e, $event.target.value)"
                                class="rounded-lg border border-border px-2.5 py-1.5 text-xs outline-none focus:border-accent"
                                :class="STYLES[e.status]">
                            <template x-for="s in ['ON_DUTY', 'ON_BREAK', 'ABSENT', 'OFF']" :key="s">
                                <option :value="s" :selected="s === e.status" x-text="LABELS[s]"></option>
                            </template>
                        </select>
                    </td>
                    <td class="px-5 py-3">
                        <div class="flex items-center justify-end gap-1.5">
                            <button type="button" @click="openEdit(e)" aria-label="Edit"
                                    class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-accent-soft hover:text-accent">
                                <i data-lucide="pencil" class="h-4 w-4"></i>
                            </button>
                            <button type="button" @click="remove(e)" aria-label="Delete"
                                    class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-danger-soft hover:text-danger">
                                <i data-lucide="trash-2" class="h-4 w-4"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            </template>
            <tr x-show="pageRows.length === 0" x-cloak>
                <td colspan="6" class="px-5 py-12 text-center text-sm text-fg-muted">No staff match your filters.</td>
            </tr>
            </tbody>
        </table>
    </div>

    <div class="flex items-center justify-between text-sm text-fg-muted">
        <span x-text="`${filtered.length} staff · page ${safePage + 1} of ${pageCount}`"></span>
        <div class="flex items-center gap-2">
            <button type="button" @click="page = Math.max(0, safePage - 1)" :disabled="safePage === 0" aria-label="Previous page"
                    class="grid h-8 w-8 place-items-center rounded-lg border border-border transition-colors hover:border-accent/40 disabled:opacity-40">
                <i data-lucide="chevron-left" class="h-4 w-4"></i>
            </button>
            <button type="button" @click="page = Math.min(pageCount - 1, safePage + 1)" :disabled="safePage >= pageCount - 1" aria-label="Next page"
                    class="grid h-8 w-8 place-items-center rounded-lg border border-border transition-colors hover:border-accent/40 disabled:opacity-40">
                <i data-lucide="chevron-right" class="h-4 w-4"></i>
            </button>
        </div>
    </div>

    <x-biz.modal show="formOpen" close="formOpen = false" title-expr="editing ? 'Edit staff' : 'Add staff'">
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
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="{{ $label }}">Role</label>
                    <select x-model="form.role" class="{{ $field }} appearance-none">
                        @foreach ($roles as $r)
                            <option value="{{ $r }}">{{ $r }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    <label class="{{ $label }}">
                        Password <span x-show="editing" class="font-normal text-fg-muted">(leave blank to keep)</span>
                    </label>
                    <input type="password" x-model="form.password" class="{{ $field }}" :placeholder="editing ? '••••••••' : 'Min 6 characters'" autocomplete="new-password">
                    <p x-show="errors.password" x-text="errors.password" class="mt-1 text-xs text-danger"></p>
                </div>
            </div>
            <label class="flex items-center gap-2 text-sm">
                <input type="checkbox" x-model="form.active" class="h-4 w-4 accent-[var(--color-accent)]">
                Active (can be deactivated to disable the account)
            </label>
            <div class="flex justify-end gap-3 pt-2">
                <button type="button" @click="formOpen = false"
                        class="rounded-lg border border-border px-4 py-2 text-sm font-medium transition-colors hover:bg-bg">Cancel</button>
                <button type="submit" :disabled="saving"
                        class="rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep disabled:opacity-60"
                        x-text="editing ? 'Save changes' : 'Add staff'"></button>
            </div>
        </form>
    </x-biz.modal>
</div>
@endsection

@push('scripts')
<script>
    function staffManager(initial, roles) {
        const PAGE_SIZE = 12;
        const BLANK = { name: '', email: '', phone: '', password: '', role: 'Waiter', active: true };
        return {
            employees: initial,
            roles,
            LABELS: { ON_DUTY: 'On Duty', ON_BREAK: 'On Break', ABSENT: 'Absent', OFF: 'Off Shift' },
            STYLES: {
                ON_DUTY: 'bg-success-soft text-success',
                ON_BREAK: 'bg-warn-soft text-warn',
                ABSENT: 'bg-danger-soft text-danger',
                OFF: 'bg-bg text-fg-muted',
            },
            status: 'ALL',
            role: 'ALL',
            activeFilter: 'ALL',
            query: '',
            page: 0,
            formOpen: false,
            editing: null,
            saving: false,
            form: { ...BLANK },
            errors: {},

            get roleOptions() {
                return Array.from(new Set([...this.roles, ...this.employees.map((e) => e.role)]));
            },
            get filtered() {
                const q = this.query.trim().toLowerCase();
                return this.employees.filter((e) =>
                    (this.status === 'ALL' || e.status === this.status) &&
                    (this.role === 'ALL' || e.role === this.role) &&
                    (this.activeFilter === 'ALL' || (this.activeFilter === 'ACTIVE' ? e.active : !e.active)) &&
                    (q === '' || e.name.toLowerCase().includes(q) || (e.email || '').toLowerCase().includes(q)));
            },
            get pageCount() { return Math.max(1, Math.ceil(this.filtered.length / PAGE_SIZE)); },
            get safePage() { return Math.min(this.page, this.pageCount - 1); },
            get pageRows() { return this.filtered.slice(this.safePage * PAGE_SIZE, this.safePage * PAGE_SIZE + PAGE_SIZE); },

            async setDuty(e, next) {
                const prev = e.status;
                e.status = next;
                try { await api(`/staff/${e.id}/status`, { method: 'PATCH', body: { status: next } }); }
                catch (err) { e.status = prev; toast(err.message, 'error'); }
            },
            async toggleActive(e) {
                const next = !e.active;
                e.active = next;
                try { await api(`/staff/${e.id}/active`, { method: 'PATCH', body: { active: next } }); }
                catch (err) { e.active = !next; toast(err.message, 'error'); }
            },
            openAdd() {
                this.editing = null;
                this.form = { ...BLANK };
                this.errors = {};
                this.formOpen = true;
            },
            openEdit(e) {
                this.editing = e;
                this.form = {
                    name: e.name,
                    email: e.email,
                    phone: e.phone ?? '',
                    password: '',
                    role: this.roles.includes(e.role) ? e.role : 'Waiter',
                    active: e.active,
                };
                this.errors = {};
                this.formOpen = true;
            },
            async remove(e) {
                if (!confirm(`Delete staff member "${e.name}"?`)) return;
                const before = this.employees;
                this.employees = this.employees.filter((x) => x.id !== e.id);
                try { await api(`/staff/${e.id}`, { method: 'DELETE' }); }
                catch (err) { this.employees = before; toast(err.message, 'error'); }
            },
            validate() {
                const f = this.form, errs = {};
                if (f.name.trim().length < 2) errs.name = 'Name is required';
                if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email)) errs.email = 'Enter a valid email';
                if (f.password && f.password.length < 6) errs.password = 'Min 6 characters';
                this.errors = errs;
                return Object.keys(errs).length === 0;
            },
            async submit() {
                if (!this.validate()) return;
                const values = { ...this.form };
                this.saving = true;
                try {
                    if (this.editing) {
                        await api(`/staff/${this.editing.id}`, { method: 'PUT', body: values });
                        Object.assign(this.editing, {
                            name: values.name, email: values.email, phone: values.phone || undefined,
                            role: values.role, active: values.active,
                        });
                    } else {
                        const res = await api('/staff', { method: 'POST', body: values });
                        this.employees = res.employees;
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
