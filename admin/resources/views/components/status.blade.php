@props(['value', 'label' => null])
@php
    // Same colour map as the Next.js admin badges (orders, reservations, staff, gift cards, tables…).
    $map = [
        'PENDING' => 'bg-bg text-fg-muted',
        'PREPARING' => 'bg-warn-soft text-warn',
        'READY' => 'bg-info-soft text-info',
        'COMPLETED' => 'bg-success-soft text-success',
        'CANCELED' => 'bg-danger-soft text-danger',
        'CANCELLED' => 'bg-danger-soft text-danger',
        'REQUESTED' => 'bg-warn-soft text-warn',
        'CONFIRMED' => 'bg-info-soft text-info',
        'SEATED' => 'bg-accent-soft text-accent',
        'NO_SHOW' => 'bg-bg text-fg-muted',
        'ON_DUTY' => 'bg-success-soft text-success',
        'ON_BREAK' => 'bg-warn-soft text-warn',
        'ABSENT' => 'bg-danger-soft text-danger',
        'OFF' => 'bg-bg text-fg-muted',
        'ACTIVE' => 'bg-success-soft text-success',
        'INACTIVE' => 'bg-bg text-fg-muted',
        'PAID' => 'bg-info-soft text-info',
        'PENDING_PAYMENT' => 'bg-warn-soft text-warn',
        'REDEEMED' => 'bg-accent-soft text-accent',
        'EXPIRED' => 'bg-bg text-fg-muted',
        'FAILED' => 'bg-danger-soft text-danger',
        // table states (floor-data.ts STATE_UI)
        'AVAILABLE' => 'bg-success-soft text-success',
        'RESERVED' => 'bg-warn-soft text-warn',
        'OCCUPIED' => 'bg-danger-soft text-danger',
        'WAITING_PAYMENT' => 'bg-accent-soft text-accent',
        'CLEANING' => 'bg-info-soft text-info',
        'OUT_OF_SERVICE' => 'bg-bg text-fg-muted',
        'OPEN' => 'bg-accent-soft text-accent',
        'CLOSED' => 'bg-success-soft text-success',
    ];
    $cls = $map[$value] ?? 'bg-bg text-fg-muted';
    $text = $label ?? ucwords(strtolower(str_replace('_', ' ', (string) $value)));
@endphp
<span {{ $attributes->merge(['class' => "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold $cls"]) }}>{{ $text }}</span>
