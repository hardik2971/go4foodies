@props(['label', 'value', 'icon' => null, 'delta' => null, 'accent' => false, 'hint' => null])
<div {{ $attributes->merge(['class' => 'card p-5 '.($accent ? 'border-transparent bg-accent text-white' : '')]) }}>
    <div class="flex items-center justify-between gap-3">
        <p class="text-sm font-medium {{ $accent ? 'text-white/80' : 'text-fg-muted' }}">{{ $label }}</p>
        @if ($icon)
            <span class="grid h-9 w-9 place-items-center rounded-xl {{ $accent ? 'bg-white/15 text-white' : 'bg-accent-soft text-accent' }}">
                <i data-lucide="{{ $icon }}" class="h-4 w-4"></i>
            </span>
        @endif
    </div>
    <p class="mt-3 font-display text-3xl font-semibold">{{ $value }}</p>
    @if ($delta !== null)
        <p class="mt-1 text-xs font-semibold {{ $accent ? 'text-white/85' : ($delta >= 0 ? 'text-success' : 'text-danger') }}">
            {{ $delta >= 0 ? '+' : '' }}{{ number_format((float) $delta, 1) }}% <span class="font-normal opacity-80">vs last month</span>
        </p>
    @elseif ($hint)
        <p class="mt-1 text-xs {{ $accent ? 'text-white/80' : 'text-fg-muted' }}">{{ $hint }}</p>
    @endif
</div>
