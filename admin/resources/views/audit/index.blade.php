@extends('layouts.app')

@php
    use App\Support\Format;
    use Carbon\Carbon;

    $ACTION_CLS = [
        'open' => 'bg-success-soft text-success',
        'close' => 'bg-accent-soft text-accent',
        'add' => 'bg-info-soft text-info',
        'void' => 'bg-danger-soft text-danger',
        'merge' => 'bg-warn-soft text-warn',
        'state' => 'bg-bg text-fg-muted',
        'payment' => 'bg-info-soft text-info',
    ];
    $cls = function (string $action) use ($ACTION_CLS) {
        $parts = explode('.', $action);
        $key = $parts[1] ?? $parts[0];

        return $ACTION_CLS[$key] ?? 'bg-bg text-fg-muted';
    };
@endphp

@section('content')
<div class="card overflow-x-auto">
    <table class="w-full text-sm">
        <thead>
        <tr class="border-b border-border text-left text-xs uppercase tracking-wide text-fg-muted">
            <th class="px-5 py-3 font-medium">When</th>
            <th class="px-5 py-3 font-medium">Action</th>
            <th class="px-5 py-3 font-medium">Entity</th>
            <th class="px-5 py-3 font-medium">Detail</th>
            <th class="px-5 py-3 font-medium">By</th>
        </tr>
        </thead>
        <tbody>
        @forelse ($logs as $l)
            <tr class="border-b border-border last:border-0 hover:bg-bg/60">
                <td class="whitespace-nowrap px-5 py-3 text-fg-muted">{{ Format::local(Carbon::parse($l['createdAt']))->format('M j, g:i A') }}</td>
                <td class="px-5 py-3">
                    <span class="rounded-md px-2 py-0.5 text-xs font-semibold {{ $cls($l['action']) }}">{{ $l['action'] }}</span>
                </td>
                <td class="px-5 py-3 text-fg-muted">{{ $l['entity'] }}</td>
                <td class="px-5 py-3 text-fg-muted">{{ $l['detail'] ?? '—' }}</td>
                <td class="px-5 py-3">{{ $l['userName'] ?? 'System' }}</td>
            </tr>
        @empty
            <tr><td colspan="5" class="px-5 py-12 text-center text-sm text-fg-muted">No activity logged yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
