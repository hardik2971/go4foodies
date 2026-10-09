{{--
  Alpine modal. Open with: $dispatch('open-modal', '<name>'), close with $dispatch('close-modal', '<name>')
  or from inside: @click="open = false".
  <x-modal name="edit-item" title="Edit item" maxWidth="max-w-lg"> … </x-modal>
--}}
@props(['name', 'title' => null, 'maxWidth' => 'max-w-lg'])
<div x-data="{ open: false }"
     x-on:open-modal.window="if ($event.detail === @js($name)) open = true"
     x-on:close-modal.window="if ($event.detail === @js($name)) open = false"
     x-on:keydown.escape.window="open = false"
     x-show="open" x-cloak
     class="fixed inset-0 z-40 flex items-center justify-center p-4">
    <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" @click="open = false"></div>
    <div x-show="open" x-transition
         class="relative w-full {{ $maxWidth }} max-h-[90vh] overflow-y-auto rounded-card border border-border bg-surface p-6 shadow-pop">
        @if ($title)
            <div class="mb-4 flex items-center justify-between gap-4">
                <h2 class="font-display text-xl font-semibold">{{ $title }}</h2>
                <button type="button" @click="open = false" class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted hover:bg-surface-2" aria-label="Close">
                    <i data-lucide="x" class="h-4 w-4"></i>
                </button>
            </div>
        @endif
        {{ $slot }}
    </div>
</div>
