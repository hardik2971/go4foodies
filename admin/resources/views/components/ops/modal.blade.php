{{--
  Modal driven by the parent Alpine scope — port of components/ui/Modal.tsx.
  <x-ops.modal show="active" close="active = null" title="Edit item" />   (static title)
  <x-ops.modal show="active" close="active = null" title-expr="active?.number" />
--}}
@props(['show', 'close', 'title' => null, 'titleExpr' => null, 'maxWidth' => 'max-w-lg'])
<template x-teleport="body">
    <div x-show="{{ $show }}" x-cloak @keydown.escape.window="if ({{ $show }}) { {{ $close }} }"
         class="fixed inset-0 z-50 grid place-items-center p-4">
        <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" @click="{{ $close }}" aria-hidden="true"></div>
        <div role="dialog" aria-modal="true"
             {{ $attributes->merge(['class' => "relative z-10 max-h-[90vh] w-full $maxWidth overflow-y-auto rounded-2xl border border-border bg-surface p-6 shadow-pop"]) }}>
            <div class="mb-4 flex items-center justify-between">
                @if ($titleExpr)
                    <h2 class="font-display text-lg font-semibold" x-text="{{ $titleExpr }}"></h2>
                @else
                    <h2 class="font-display text-lg font-semibold">{{ $title }}</h2>
                @endif
                <button type="button" @click="{{ $close }}" aria-label="Close"
                        class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-bg hover:text-fg">
                    <i data-lucide="x" class="h-4 w-4"></i>
                </button>
            </div>
            {{ $slot }}
        </div>
    </div>
</template>
