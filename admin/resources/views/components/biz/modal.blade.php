{{-- Port of components/ui/Modal.tsx driven by an Alpine expression (open state lives in the
     page component):  <x-biz.modal show="formOpen" close="formOpen = false" title-expr="editing ? 'Edit staff' : 'Add staff'"> --}}
@props(['show', 'close', 'title' => null, 'titleExpr' => null])
<template x-teleport="body">
    <div x-show="{{ $show }}" x-cloak @keydown.escape.window="if ({{ $show }}) { {{ $close }} }"
         class="fixed inset-0 z-50 grid place-items-center p-4">
        <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" @click="{{ $close }}" aria-hidden="true"></div>
        <div role="dialog" aria-modal="true"
             class="relative z-10 max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-2xl border border-border bg-surface p-6 shadow-pop">
            <div class="mb-4 flex items-center justify-between">
                <h2 class="font-display text-lg font-semibold" @if ($titleExpr) x-text="{{ $titleExpr }}" @endif>{{ $title }}</h2>
                <button type="button" @click="{{ $close }}" aria-label="Close"
                        class="grid h-8 w-8 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-bg hover:text-fg">
                    <i data-lucide="x" class="h-4 w-4"></i>
                </button>
            </div>
            {{ $slot }}
        </div>
    </div>
</template>
