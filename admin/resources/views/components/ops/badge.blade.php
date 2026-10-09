{{--
  Status badge with a leading dot — port of components/orders/StatusBadge.tsx and
  components/reservations/ResStatusBadge.tsx.  <x-ops.badge :status="$o['status']" kind="order|reservation" />
--}}
@props(['status', 'kind' => 'order'])
@php
    $styles = [
        'PENDING' => 'bg-bg text-fg-muted',
        'PREPARING' => 'bg-warn-soft text-warn',
        'READY' => 'bg-info-soft text-info',
        'COMPLETED' => 'bg-success-soft text-success',
        'CANCELED' => 'bg-danger-soft text-danger',
        'REQUESTED' => 'bg-warn-soft text-warn',
        'CONFIRMED' => 'bg-info-soft text-info',
        'SEATED' => 'bg-accent-soft text-accent',
        'NO_SHOW' => 'bg-bg text-fg-muted',
    ];
    $labels = $kind === 'reservation'
        ? ['REQUESTED' => 'Pending', 'CONFIRMED' => 'Confirmed', 'SEATED' => 'Checked In', 'COMPLETED' => 'Completed', 'CANCELED' => 'Cancelled', 'NO_SHOW' => 'No-show']
        : ['PENDING' => 'Pending', 'PREPARING' => 'Preparing', 'READY' => 'Ready', 'COMPLETED' => 'Completed', 'CANCELED' => 'Canceled'];
@endphp
<span {{ $attributes->merge(['class' => 'inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-semibold '.($styles[$status] ?? 'bg-bg text-fg-muted')]) }}>
    <span class="h-1.5 w-1.5 rounded-full bg-current"></span>
    {{ $labels[$status] ?? $status }}
</span>
