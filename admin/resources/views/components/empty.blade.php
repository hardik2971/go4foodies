@props(['icon' => 'inbox', 'title' => 'Nothing here yet', 'message' => null])
<div {{ $attributes->merge(['class' => 'flex flex-col items-center justify-center gap-2 px-6 py-14 text-center']) }}>
    <span class="grid h-14 w-14 place-items-center rounded-full bg-accent-soft text-accent"><i data-lucide="{{ $icon }}" class="h-6 w-6"></i></span>
    <p class="mt-2 font-display text-lg font-semibold">{{ $title }}</p>
    @if ($message)<p class="max-w-sm text-sm text-fg-muted">{{ $message }}</p>@endif
    {{ $slot }}
</div>
