import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'customer_providers.dart';

const _occasions = ['Casual Dining', 'Birthday', 'Anniversary', 'Business', 'Date Night', 'Celebration'];
const _eventTypes = ['Birthday', 'Corporate Dinner', 'Wedding / Engagement', 'Cocktail Party', 'Holiday Party', 'Other'];
const _guestRanges = ['10–20', '20–40', '40–70', '70–120', '120+'];
const _spaces = ['Main Dining', 'Private Room', 'Bar Area', 'Full Buyout'];

void openReservationForm(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReservationFormScreen()));

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-booking'),
        backgroundColor: AppColors.goldBrand,
        foregroundColor: AppColors.ink,
        onPressed: () => openReservationForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Book', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: AsyncBody<List<Json>>(
        value: ref.watch(myReservationsProvider),
        onRefresh: () async => ref.refresh(myReservationsProvider.future),
        builder: (list) => list.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                EmptyState(icon: Icons.event_seat_outlined, title: 'No bookings yet', message: 'Reserve a table or plan a private event.'),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ReservationTile(reservation: list[i], showActions: true),
              ),
      ),
    );
  }
}

class ReservationTile extends ConsumerWidget {
  const ReservationTile({super.key, required this.reservation, this.showActions = false});
  final Json reservation;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reservation;
    final isEvent = r['kind'] == 'PRIVATE_EVENT';
    final cancellable = showActions && (r['status'] == 'REQUESTED' || r['status'] == 'CONFIRMED');
    final d = parseDate(r['date']);
    final c = context.c;
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(d == null ? '' : DateFormat('MMM').format(d).toUpperCase(), style: TextStyle(color: c.accent, fontSize: 11, fontWeight: FontWeight.w800)),
            Text(d == null ? '' : '${d.day}', style: display(context, size: 22)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(isEvent ? (r['eventType'] as String? ?? 'Private event') : 'Table for ${r['guests'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
              StatusChip(r['status'] as String),
            ]),
            const SizedBox(height: 4),
            Text(
              isEvent ? '${r['space'] ?? ''} · ${r['guestRange'] ?? ''} guests' : '${fmtDate(r['date'], 'EEEE')} at ${fmtSlot(r['time'] as String?)}${r['occasion'] != null ? ' · ${r['occasion']}' : ''}',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text('Ref ${r['reference']}', style: TextStyle(color: c.muted, fontSize: 12)),
            if (cancellable)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    if (!await confirm(context, title: 'Cancel booking?', message: 'Ref ${r['reference']}', confirmLabel: 'Cancel booking', destructive: true)) return;
                    if (!context.mounted) return;
                    await guard(context, () async {
                      await ref.read(apiProvider).post('/api/mobile/customer/reservations/${r['id']}/cancel');
                      ref.invalidate(myReservationsProvider);
                      ref.invalidate(customerHomeProvider);
                    }, success: 'Booking cancelled');
                  },
                  style: TextButton.styleFrom(foregroundColor: c.danger),
                  child: const Text('Cancel'),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class ReservationFormScreen extends ConsumerStatefulWidget {
  const ReservationFormScreen({super.key});
  @override
  ConsumerState<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends ConsumerState<ReservationFormScreen> {
  String _kind = 'TABLE';
  DateTime _date = DateTime.now();
  String? _time;
  int _guests = 2;
  String _occasion = _occasions.first;
  String _eventType = _eventTypes.first;
  String _guestRange = _guestRanges.first;
  String _space = _spaces.first;
  final _requests = TextEditingController();
  final _company = TextEditingController();
  bool _busy = false;
  List<Json>? _slots;
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _requests.dispose();
    _company.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _time = null;
    });
    try {
      final res = await ref.read(apiProvider).get('/api/reservations/availability', query: {'date': ymd(_date)});
      _slots = ((res['slots'] as List?) ?? const []).cast<Json>();
    } catch (_) {
      _slots = pickupSlots(_date).map((s) => <String, dynamic>{'time': s, 'available': true, 'remaining': 6}).toList();
    }
    if (mounted) setState(() => _loadingSlots = false);
  }

  Future<void> _submit() async {
    if (_kind == 'TABLE' && _time == null) {
      toast(context, 'Choose a time', error: true);
      return;
    }
    setState(() => _busy = true);
    final body = _kind == 'TABLE'
        ? {
            'kind': 'TABLE',
            'date': ymd(_date),
            'time': _time,
            'guests': _guests,
            'occasion': _occasion,
            if (_requests.text.trim().isNotEmpty) 'requests': _requests.text.trim(),
          }
        : {
            'kind': 'PRIVATE_EVENT',
            'eventType': _eventType,
            'date': ymd(_date),
            'guestRange': _guestRange,
            'space': _space,
            if (_company.text.trim().isNotEmpty) 'company': _company.text.trim(),
            if (_requests.text.trim().isNotEmpty) 'message': _requests.text.trim(),
          };
    try {
      final res = await ref.read(apiProvider).post('/api/mobile/customer/reservations', body);
      ref.invalidate(myReservationsProvider);
      ref.invalidate(customerHomeProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.celebration_rounded, color: ctx.c.accent, size: 40),
          title: Text(_kind == 'TABLE' ? 'Table requested' : 'Enquiry sent', style: display(ctx, size: 22)),
          content: Text('Reference ${res['reference']}\nWe’ll confirm by email shortly.', textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = List.generate(30, (i) => DateTime.now().add(Duration(days: i)));
    return Scaffold(
      appBar: AppBar(title: const Text('Reserve')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'TABLE', label: Text('Table booking'), icon: Icon(Icons.table_restaurant_rounded)),
            ButtonSegment(value: 'PRIVATE_EVENT', label: Text('Private event'), icon: Icon(Icons.celebration_rounded)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SectionTitle('Date', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = days[i];
              final sel = ymd(d) == ymd(_date);
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() => _date = d);
                  _loadSlots();
                },
                child: Container(
                  width: 58,
                  decoration: BoxDecoration(color: sel ? c.accent : c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? c.accent : c.border)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(DateFormat('EEE').format(d), style: TextStyle(fontSize: 12, color: sel ? AppColors.ink : c.muted)),
                    Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: sel ? AppColors.ink : c.fg)),
                  ]),
                ),
              );
            },
          ),
        ),
        if (_kind == 'TABLE') ...[
          const SectionTitle('Time', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
          if (_loadingSlots)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else if ((_slots ?? const []).isEmpty)
            Text('No times available on this day.', style: TextStyle(color: c.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in _slots!)
                ChoiceChip(
                  label: Text(fmtSlot(s['time'] as String)),
                  selected: _time == s['time'],
                  showCheckmark: false,
                  onSelected: s['available'] == true ? (_) => setState(() => _time = s['time'] as String) : null,
                ),
            ]),
          const SectionTitle('Guests', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
          Wrap(spacing: 8, children: [
            for (var g = 1; g <= 8; g++)
              ChoiceChip(label: Text('$g'), selected: _guests == g, showCheckmark: false, onSelected: (_) => setState(() => _guests = g)),
          ]),
          const SectionTitle('Occasion', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in _occasions)
              ChoiceChip(label: Text(o), selected: _occasion == o, showCheckmark: false, onSelected: (_) => setState(() => _occasion = o)),
          ]),
        ] else ...[
          const SectionTitle('Event type', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in _eventTypes)
              ChoiceChip(label: Text(o), selected: _eventType == o, showCheckmark: false, onSelected: (_) => setState(() => _eventType = o)),
          ]),
          const SectionTitle('Guests', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in _guestRanges)
              ChoiceChip(label: Text(o), selected: _guestRange == o, showCheckmark: false, onSelected: (_) => setState(() => _guestRange = o)),
          ]),
          const SectionTitle('Space', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in _spaces)
              ChoiceChip(label: Text(o), selected: _space == o, showCheckmark: false, onSelected: (_) => setState(() => _space = o)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _company, decoration: const InputDecoration(labelText: 'Company (optional)')),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _requests,
          maxLines: 3,
          decoration: InputDecoration(labelText: _kind == 'TABLE' ? 'Special requests (optional)' : 'Tell us about your event (optional)'),
        ),
        const SizedBox(height: 12),
        Text('Booking as ${ref.read(sessionProvider).profile?.name ?? ''} · ${ref.read(sessionProvider).profile?.email ?? ''}',
            style: TextStyle(color: c.muted, fontSize: 12.5)),
      ]),
      bottomSheet: Container(
        color: c.surface,
        padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
        child: FilledButton(
          key: const Key('submit-booking'),
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink))
              : Text(_kind == 'TABLE' ? 'Request table' : 'Send enquiry'),
        ),
      ),
    );
  }
}
