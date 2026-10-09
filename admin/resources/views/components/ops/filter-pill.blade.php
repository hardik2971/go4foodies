{{-- Static header filter chip — port of components/ui/FilterPill.tsx --}}
@props(['label', 'icon' => true])
<button type="button" class="inline-flex items-center gap-2 rounded-lg border border-border bg-surface px-3 py-1.5 text-xs font-medium text-fg-muted transition-colors hover:border-accent/40">
    @if ($icon)<i data-lucide="calendar" class="h-3.5 w-3.5"></i>@endif
    {{ $label }}
    <i data-lucide="chevron-down" class="h-3.5 w-3.5"></i>
</button>
