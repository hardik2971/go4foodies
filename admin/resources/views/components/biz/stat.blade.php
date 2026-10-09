{{-- Stat tile used across the business managers (card + icon chip + label + value).
     <x-biz.stat label="Total Staff" icon="users" x-text="employees.length" />  (Alpine)
     <x-biz.stat label="Revenue" icon="dollar-sign" :value="$v" />               (static) --}}
@props(['label', 'icon', 'value' => null])
<div class="card flex items-center gap-3 p-4">
    <span class="grid h-10 w-10 place-items-center rounded-lg bg-accent-soft text-accent">
        <i data-lucide="{{ $icon }}" class="h-5 w-5"></i>
    </span>
    <div>
        <p class="text-xs text-fg-muted">{{ $label }}</p>
        <p {{ $attributes->merge(['class' => 'font-display text-xl font-semibold']) }}>{{ $value }}</p>
    </div>
</div>
