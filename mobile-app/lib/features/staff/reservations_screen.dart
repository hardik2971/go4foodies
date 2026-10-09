import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'staff_providers.dart';

/// Status transitions — mirrors admin reservations-data.ts nextStatuses().
List<String> nextReservationStatuses(String kind, String status) {
  final flow = kind == 'TABLE' ? ['REQUESTED', 'CONFIRMED', 'SEATED', 'COMPLETED'] : ['REQUESTED', 'CONFIRMED', 'COMPLETED'];
  if (status == 'COMPLETED' || status == 'CANCELED' || status == 'NO_SHOW') return const [];
  final i = flow.indexOf(status);
  return [
    if (i >= 0 && i < flow.length - 1) flow[i + 1],
    'CANCELED',
    if (kind == 'TABLE') 'NO_SHOW',
  ];
}

class StaffReservationsScreen extends ConsumerStatefulWidget {
  const StaffReservationsScreen({super.key});
  @override
  ConsumerState<StaffReservationsScreen> createState() => _StaffReservationsScreenState();
}

class _StaffReservationsScreenState extends ConsumerState<StaffReservationsScreen> {
  String _range = 'Today';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservations')),
      body: AsyncBody<List<Json>>(
        value: ref.watch(staffReservationsProvider),
        onRefresh: () async => ref.refresh(staffReservationsProvider.future),
        builder: (all) {
          final today = DateTime.now();
          bool sameDay(DateTime d) => d.year == today.year && d.month == today.month && d.day == today.day;
          final list = all.where((r) {
            final d = parseDate(r['date']);
            if (d == null) return _range == 'All';
            return switch (_range) {
              'Today' => sameDay(d),
              'Upcoming' => d.isAfter(DateTime(today.year, today.month, today.day)) || sameDay(d),
              'Requests' => r['status'] == 'REQUESTED',
              _ => true,
            };
          }).toList()
            ..sort((a, b) => '${a['date']}${a['time'] ?? ''}'.compareTo('${b['date']}${b['time'] ?? ''}'));
          if (_range == 'All') list.setAll(0, list.reversed.toList());
          final requested = all.where((r) => r['status'] == 'REQUESTED').length;

          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Wrap(spacing: 8, children: [
              for (final r in ['Today', 'Upcoming', 'Requests', 'All'])
                ChoiceChip(
                  label: Text(r == 'Requests' && requested > 0 ? 'Requests ($requested)' : r),
                  selected: _range == r,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _range = r),
                ),
            ]),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: Icons.event_busy_rounded, title: 'No reservations')),
            for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ReservationCard(r: r)),
          ]);
        },
      ),
    );
  }
}

class _ReservationCard extends ConsumerWidget {
  const _ReservationCard({required this.r});
  final Json r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final isEvent = r['kind'] == 'PRIVATE_EVENT';
    final next = nextReservationStatuses(r['kind'] as String, r['status'] as String);
    final d = parseDate(r['date']);
    return AppCard(
      onTap: () => _details(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isEvent ? Icons.celebration_rounded : Icons.table_restaurant_rounded, size: 18, color: c.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800))),
          StatusChip(r['status'] as String),
        ]),
        const SizedBox(height: 6),
        Text(
          isEvent
              ? '${r['eventType']} · ${r['guestRange']} guests · ${r['space']} · ${d == null ? '' : DateFormat('EEE d MMM').format(d)}'
              : '${r['guests']} guests · ${d == null ? '' : DateFormat('EEE d MMM').format(d)} · ${fmtSlot(r['time'] as String?)}${r['occasion'] != null ? ' · ${r['occasion']}' : ''}',
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
        Text('${r['reference']} · ${r['phone']}', style: TextStyle(color: c.muted, fontSize: 12)),
        if (next.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final s in next)
              (s == 'CANCELED' || s == 'NO_SHOW')
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: c.danger),
                      onPressed: () => _set(context, ref, s),
                      child: Text(humanize(s)),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 16)),
                      onPressed: () => _set(context, ref, s),
                      child: Text(s == 'CONFIRMED' ? 'Confirm' : s == 'SEATED' ? 'Seat' : humanize(s)),
                    ),
          ]),
        ],
      ]),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, String status) => guard(context, () async {
        await ref.read(apiProvider).patch('$staffApi/reservations/${r['id']}/status', {'status': status});
        ref.invalidate(staffReservationsProvider);
      }, success: '${r['reference']} → ${humanize(status)}');

  void _details(BuildContext context) {
    final fields = <(String, Object?)>[
      ('Reference', r['reference']),
      ('Email', r['email']),
      ('Phone', r['phone']),
      ('Date', fmtDate(r['date'], 'EEEE d MMMM y')),
      if (r['time'] != null) ('Time', fmtSlot(r['time'] as String)),
      if (r['guests'] != null) ('Guests', r['guests']),
      if (r['occasion'] != null) ('Occasion', r['occasion']),
      if (r['requests'] != null) ('Requests', r['requests']),
      if (r['eventType'] != null) ('Event', r['eventType']),
      if (r['guestRange'] != null) ('Guests', r['guestRange']),
      if (r['space'] != null) ('Space', r['space']),
      if (r['company'] != null) ('Company', r['company']),
      if (r['message'] != null) ('Message', r['message']),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['name'] as String, style: display(ctx, size: 22)),
            const SizedBox(height: 12),
            for (final f in fields) KeyValue(f.$1, '${f.$2}'),
          ]),
        ),
      ),
    );
  }
}

