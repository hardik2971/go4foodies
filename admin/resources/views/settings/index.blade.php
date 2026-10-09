@extends('layouts.app')

@php
    use App\Support\Rbac;

    $field = 'w-full rounded-lg border border-border bg-surface px-3.5 py-2.5 text-sm outline-none transition-colors focus:border-accent';
    $label = 'mb-1.5 block text-sm font-medium';

    $ROLES = ['OWNER', 'MANAGER', 'STAFF'];
    $ACTIONS = [
        ['view:dashboard', 'Dashboard'],
        ['manage:orders', 'Orders'],
        ['manage:menu', 'Menu'],
        ['manage:reservations', 'Reservations'],
        ['manage:outlets', 'Outlets'],
        ['manage:staff', 'Staff'],
        ['manage:customers', 'Customers'],
        ['manage:inventory', 'Inventory'],
        ['view:reports', 'Reports'],
        ['manage:settings', 'Settings'],
    ];
    $ROLE_BADGE = [
        'OWNER' => 'bg-accent-soft text-accent',
        'MANAGER' => 'bg-info-soft text-info',
        'STAFF' => 'bg-bg text-fg-muted',
    ];
@endphp

@section('content')
<div class="grid grid-cols-1 gap-5 lg:grid-cols-2">
    {{-- Restaurant Profile --}}
    <section class="card p-6" x-data="profileForm(@js($profile))">
        <h2 class="font-display text-lg font-semibold">Restaurant Profile</h2>
        <p class="mt-1 text-sm text-fg-muted">Brand name, currency, and contact details.</p>
        <div class="mt-5">
            <form @submit.prevent="submit()" class="space-y-4" novalidate>
                <div>
                    <label class="{{ $label }}">Restaurant name</label>
                    <input x-model="form.name" class="{{ $field }}">
                    <p x-show="errors.name" x-text="errors.name" class="mt-1 text-xs text-danger"></p>
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="{{ $label }}">Currency</label>
                        <input x-model="form.currency" class="{{ $field }}" placeholder="USD">
                    </div>
                    <div>
                        <label class="{{ $label }}">Timezone</label>
                        <input x-model="form.timezone" class="{{ $field }}" placeholder="America/New_York">
                    </div>
                </div>
                <div>
                    <label class="{{ $label }}">Address</label>
                    <input x-model="form.address" class="{{ $field }}">
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="{{ $label }}">Phone</label>
                        <input x-model="form.phone" class="{{ $field }}">
                    </div>
                    <div>
                        <label class="{{ $label }}">Email</label>
                        <input x-model="form.email" class="{{ $field }}">
                        <p x-show="errors.email" x-text="errors.email" class="mt-1 text-xs text-danger"></p>
                    </div>
                </div>
                <div class="flex items-center gap-3">
                    <button type="submit" :disabled="submitting"
                            class="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep disabled:opacity-60">
                        <span x-show="submitting" x-cloak class="inline-flex"><i data-lucide="loader-circle" class="h-4 w-4 animate-spin"></i></span>
                        Save changes
                    </button>
                    <span x-show="saved" x-cloak class="inline-flex items-center gap-1 text-sm text-success">
                        <i data-lucide="check" class="h-4 w-4"></i> Saved
                    </span>
                </div>
            </form>
        </div>
    </section>

    {{-- Change Password --}}
    <section class="card p-6" x-data="passwordForm()">
        <h2 class="font-display text-lg font-semibold">Change Password</h2>
        <p class="mt-1 text-sm text-fg-muted">Update your account password.</p>
        <div class="mt-5">
            <form @submit.prevent="submit()" class="space-y-4" novalidate>
                <p x-show="msg" x-cloak class="rounded-lg px-3 py-2 text-sm"
                   :class="msg && msg.ok ? 'bg-success-soft text-success' : 'bg-danger-soft text-danger'" x-text="msg ? msg.text : ''"></p>
                <div>
                    <label class="{{ $label }}">Current password</label>
                    <input type="password" x-model="form.currentPassword" class="{{ $field }}" autocomplete="current-password">
                    <p x-show="errors.currentPassword" x-text="errors.currentPassword" class="mt-1 text-xs text-danger"></p>
                </div>
                <div>
                    <label class="{{ $label }}">New password</label>
                    <input type="password" x-model="form.newPassword" class="{{ $field }}" autocomplete="new-password">
                    <p x-show="errors.newPassword" x-text="errors.newPassword" class="mt-1 text-xs text-danger"></p>
                </div>
                <button type="submit" :disabled="submitting"
                        class="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-deep disabled:opacity-60">
                    <span x-show="submitting" x-cloak class="inline-flex"><i data-lucide="loader-circle" class="h-4 w-4 animate-spin"></i></span>
                    Update password
                </button>
            </form>
        </div>
    </section>

    {{-- Team --}}
    <section class="card p-6">
        <h2 class="font-display text-lg font-semibold">Team</h2>
        <p class="mt-1 text-sm text-fg-muted">Signed in as {{ $account['name'] }} ({{ $account['role'] }}).</p>
        <div class="mt-5">
            <ul class="divide-y divide-border">
                @foreach ($team as $m)
                    <li class="flex items-center justify-between py-2.5">
                        <div>
                            <p class="text-sm font-medium">{{ $m['name'] }}</p>
                            <p class="text-xs text-fg-muted">{{ $m['email'] }}</p>
                        </div>
                        <span class="rounded-md px-2 py-0.5 text-xs font-semibold {{ $ROLE_BADGE[$m['role']] ?? '' }}">{{ $m['role'] }}</span>
                    </li>
                @endforeach
            </ul>
        </div>
    </section>

    {{-- Roles & Permissions --}}
    <section class="card p-6">
        <h2 class="font-display text-lg font-semibold">Roles &amp; Permissions</h2>
        <p class="mt-1 text-sm text-fg-muted">What each role can access.</p>
        <div class="mt-5">
            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead>
                    <tr class="text-left text-xs uppercase tracking-wide text-fg-muted">
                        <th class="py-2 pr-3 font-medium">Module</th>
                        @foreach ($ROLES as $r)
                            <th class="px-2 py-2 text-center font-medium">{{ $r }}</th>
                        @endforeach
                    </tr>
                    </thead>
                    <tbody>
                    @foreach ($ACTIONS as [$action, $name])
                        <tr class="border-t border-border">
                            <td class="py-2 pr-3">{{ $name }}</td>
                            @foreach ($ROLES as $r)
                                <td class="px-2 py-2 text-center">
                                    @if (Rbac::can($r, $action))
                                        <i data-lucide="check" class="mx-auto h-4 w-4 text-success"></i>
                                    @else
                                        <span class="text-fg-muted">—</span>
                                    @endif
                                </td>
                            @endforeach
                        </tr>
                    @endforeach
                    </tbody>
                </table>
            </div>
        </div>
    </section>
</div>
@endsection

@push('scripts')
<script>
    function profileForm(profile) {
        return {
            form: { ...profile },
            errors: {},
            submitting: false,
            saved: false,
            async submit() {
                const f = this.form, errs = {};
                if (String(f.name || '').trim().length < 2) errs.name = 'Restaurant name is required';
                if (f.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email)) errs.email = 'Enter a valid email';
                this.errors = errs;
                if (Object.keys(errs).length) return;
                this.saved = false;
                this.submitting = true;
                try {
                    await api('/settings/profile', { method: 'PUT', body: f });
                    this.saved = true;
                } catch (err) {
                    toast(err.message, 'error');
                } finally {
                    this.submitting = false;
                }
            },
        };
    }

    function passwordForm() {
        return {
            form: { currentPassword: '', newPassword: '' },
            errors: {},
            msg: null,
            submitting: false,
            async submit() {
                const f = this.form, errs = {};
                if (!f.currentPassword) errs.currentPassword = 'Current password is required';
                if (f.newPassword.length < 6) errs.newPassword = 'New password must be at least 6 characters';
                this.errors = errs;
                if (Object.keys(errs).length) return;
                this.msg = null;
                this.submitting = true;
                let res;
                try {
                    res = await api('/settings/password', { method: 'POST', body: f });
                } catch (err) {
                    res = { ok: false, error: 'Something went wrong' };
                }
                if (res.ok) {
                    this.msg = { ok: true, text: 'Password updated' };
                    this.form = { currentPassword: '', newPassword: '' };
                } else {
                    this.msg = { ok: false, text: res.error ?? 'Failed' };
                }
                this.submitting = false;
            },
        };
    }
</script>
@endpush
