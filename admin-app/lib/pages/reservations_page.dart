import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/ops_widgets.dart';
import '../widgets/ui.dart';

/// Reservations — port of resources/views/reservations/index.blade.php (ReservationsManager + ReservationDetail).
class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => asJson(await Api.get('/reservations')),
        builder: (context, data, _) => _ReservationsView(items: asJsonList(data['reservations'])),
      );
}

const _flows = {
  'TABLE': ['REQUESTED', 'CONFIRMED', 'SEATED', 'COMPLETED'],
  'PRIVATE_EVENT': ['REQUESTED', 'CONFIRMED', 'COMPLETED'],
};
const _kindLabels = {'TABLE': 'Table Booking', 'PRIVATE_EVENT': 'Private Event'};
const _statusLabels = {'REQUESTED': 'Pending', 'CONFIRMED': 'Confirmed', 'SEATED': 'Checked In', 'COMPLETED': 'Completed', 'CANCELED': 'Cancelled', 'NO_SHOW': 'No-show'};
const _statusFilters = ['ALL', 'REQUESTED', 'CONFIRMED', 'SEATED', 'COMPLETED', 'CANCELED', 'NO_SHOW'];

String _dateKey(dynamic d) {
  final v = str(d);
  return v.length >= 10 ? v.substring(0, 10) : v;
}

class _ReservationsView extends StatefulWidget {
  const _ReservationsView({required this.items});
  final List<Json> items;
  @override
  State<_ReservationsView> createState() => _ReservationsViewState();
}

class _ReservationsViewState extends State<_ReservationsView> {
  late List<Json> items = widget.items;
  String status = 'ALL', kind = 'ALL', date = '', query = '';
  Json? active;
  bool editing = false;
  final rev = Rev();
  final dDate = TextEditingController(), dTime = TextEditingController(), dGuests = TextEditingController();
  final dOccasion = TextEditingController(), dRequests = TextEditingController();

  @override
  void dispose() {
    for (final c in [dDate, dTime, dGuests, dOccasion, dRequests]) {
      c.dispose();
    }
    rev.dispose();
    super.dispose();
  }

  void update(VoidCallback fn) {
    if (mounted) setState(fn);
    rev.bump();
  }

  List<Json> get filtered {
    final q = query.trim().toLowerCase();
    return items
        .where((r) =>
            (status == 'ALL' || r['status'] == status) &&
            (kind == 'ALL' || r['kind'] == kind) &&
            (date.isEmpty || _dateKey(r['date']) == date) &&
            (q.isEmpty ||
                str(r['reference']).toLowerCase().contains(q) ||
                str(r['name']).toLowerCase().contains(q) ||
                str(r['email']).toLowerCase().contains(q)))
        .toList();
  }

  List<String> flowOf(Json r) => _flows[r['kind']] ?? _flows['PRIVATE_EVENT']!;
  bool isOff(Json r) => r['status'] == 'CANCELED' || r['status'] == 'NO_SHOW';
  bool isClosed(Json r) => const ['COMPLETED', 'CANCELED', 'NO_SHOW'].contains(r['status']);

  List<String> nextStatuses(Json r) {
    if (isClosed(r)) return [];
    final flow = flowOf(r);
    final idx = flow.indexOf(str(r['status']));
    final forward = idx >= 0 && idx < flow.length - 1 ? [flow[idx + 1]] : <String>[];
    return [...forward, ...(r['kind'] == 'TABLE' ? ['CANCELED', 'NO_SHOW'] : ['CANCELED'])];
  }

  Future<void> open(Json r) async {
    setState(() {
      editing = false;
      active = r;
    });
    await showAppModal(context, title: str(r['reference']), builder: (ctx) => synced(rev, () => active == null ? const SizedBox() : _detail(ctx, active!)));
    if (mounted) setState(() => active = null);
  }

  void startEdit() {
    final r = active!;
    dDate.text = _dateKey(r['date']);
    dTime.text = str(r['time']);
    dGuests.text = jsNum(r['guests']);
    dOccasion.text = str(r['occasion']);
    dRequests.text = str(r['requests']);
    update(() => editing = true);
  }

  void save() {
    final id = active!['id'];
    final g = dGuests.text.trim();
    final patch = <String, dynamic>{
      'date': dDate.text,
      'time': dTime.text,
      'guests': g.isEmpty ? '' : (num.tryParse(g) ?? g),
      'occasion': dOccasion.text,
      'requests': dRequests.text,
    };
    Json apply(Json r) => {
          ...r,
          if (has(patch['date'])) 'date': patch['date'],
          'time': patch['time'],
          'guests': patch['guests'],
          'occasion': patch['occasion'],
          'requests': patch['requests'],
        };
    update(() {
      items = [for (final r in items) r['id'] == id ? apply(r) : r];
      active = {...active!, ...patch};
      editing = false;
    });
    guard(() => Api.patch('/reservations/$id', patch));
  }

  void changeStatus(String id, String next) {
    update(() {
      items = [for (final r in items) r['id'] == id ? {...r, 'status': next} : r];
      if (active != null && active!['id'] == id) active = {...active!, 'status': next};
    });
    guard(() => Api.patch('/reservations/$id/status', {'status': next}));
  }

  Widget badge(String st) => toneBadge(context, st, _statusLabels[st] ?? st, dot: true);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = filtered;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TileGrid(minWidth: 160, children: [
        StatTile(icon: LucideIcons.calendarClock, label: 'Total', value: '${items.length}'),
        StatTile(icon: LucideIcons.users, label: 'New Requests', value: '${items.where((r) => r['status'] == 'REQUESTED').length}'),
        StatTile(icon: LucideIcons.circleCheck, label: 'Confirmed', value: '${items.where((r) => r['status'] == 'CONFIRMED' || r['status'] == 'SEATED').length}'),
        StatTile(icon: LucideIcons.partyPopper, label: 'Private Events', value: '${items.where((r) => r['kind'] == 'PRIVATE_EVENT').length}'),
      ]),
      const SizedBox(height: 20),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        FilterPills<String>(
          options: _statusFilters,
          value: status,
          label: (s) => s == 'ALL' ? 'All' : _statusLabels[s]!,
          onChanged: (v) => setState(() => status = v),
        ),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Tooltip(
            message: 'Filter by date',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final v = await pickDateValue(context, date);
                if (v != null) setState(() => date = v);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(dateInputLabel(date), style: TextStyle(fontSize: 14, color: c.fgMuted)),
                  const SizedBox(width: 10),
                  Icon(LucideIcons.calendar, size: 16, color: c.fgMuted),
                ]),
              ),
            ),
          ),
          if (date.isNotEmpty) LinkBtn('Clear date', onTap: () => setState(() => date = '')),
          AppSelect<String>(
            value: kind,
            items: const [('ALL', 'All kinds'), ('TABLE', 'Table Booking'), ('PRIVATE_EVENT', 'Private Event')],
            onChanged: (v) => setState(() => kind = v),
          ),
          SearchField(hint: 'Search ref, name, email…', width: 224, onChanged: (v) => setState(() => query = v)),
        ]),
      ]),
      const SizedBox(height: 20),
      DataTableCard(
        columns: const [
          DataCol('Reference', flex: 3),
          DataCol('Guest', flex: 3),
          DataCol('Kind', flex: 2),
          DataCol('Date', flex: 2),
          DataCol('Party', flex: 2),
          DataCol('Status', flex: 2),
          DataCol('View', align: TextAlign.right),
        ],
        empty: 'No reservations match your filters.',
        onRowTap: (i) => open(rows[i]),
        rows: [
          for (final r in rows)
            [
              Row(children: [
                Tooltip(
                  message: _kindLabels[r['kind']] ?? '',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(8)),
                    child: Icon(r['kind'] == 'TABLE' ? LucideIcons.utensils : LucideIcons.partyPopper, size: 16, color: c.accent),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(str(r['reference']), style: const TextStyle(fontWeight: FontWeight.w500))),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(str(r['name'])), Muted(str(r['email']), size: 12)]),
              Muted(_kindLabels[r['kind']] ?? '', size: 14),
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Icon(LucideIcons.calendarClock, size: 14, color: c.fgMuted),
                Text(fmtDate(r['date'], 'MMM d')),
                if (has(r['time'])) Muted('· ${r['time']}', size: 14),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.users, size: 14, color: c.fgMuted),
                const SizedBox(width: 6),
                Flexible(child: Muted(r['kind'] == 'TABLE' ? '${r['guests']} guests' : str(r['guestRange']), size: 14)),
              ]),
              badge(str(r['status'])),
              Padding(padding: const EdgeInsets.all(8), child: Icon(LucideIcons.eye, size: 16, color: c.fgMuted)),
            ],
        ],
        footer: 'Showing ${rows.length} of ${items.length} reservations. Once MySQL is live, bookings submitted on the public site land here automatically.',
      ),
    ]);
  }

  Widget _detail(BuildContext ctx, Json r) {
    final c = ctx.c;
    final st = str(r['status']);
    final flow = flowOf(r);
    final flowIndex = isOff(r) ? -1 : flow.indexOf(st);
    final isTable = r['kind'] == 'TABLE';
    const gap = SizedBox(height: 20);
    final rows = <(String, dynamic)>[
      ('Date', fmtDate(r['date'], 'EEE, MMM d, yyyy')),
      if (isTable) ...[('Time', r['time']), ('Guests', r['guests']), ('Occasion', r['occasion']), ('Requests', r['requests'])]
      else ...[('Event type', r['eventType']), ('Estimated guests', r['guestRange']), ('Space', r['space']), ('Company', r['company']), ('Details', r['message'])],
    ].where((e) => e.$2 != null && e.$2 != '').toList();
    final next = nextStatuses(r);

    Widget contact(IconData icon, String text, String href) => InkWell(
          onTap: () => launchUrl(Uri.parse(href)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(icon, size: 16, color: c.fgMuted),
              const SizedBox(width: 8),
              Flexible(child: Text(text, style: TextStyle(fontSize: 14, color: c.fgMuted))),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        TinyPill(_kindLabels[r['kind']] ?? '', fg: c.accent, bg: c.accentSoft, uppercase: false, size: 12),
        const Spacer(),
        badge(st),
      ]),
      gap,
      Boxed(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FlowStepper(labels: [for (final s in flow) _statusLabels[s]!], current: flowIndex),
          if (isOff(r)) DangerNote('This reservation was ${(_statusLabels[st] ?? st).toLowerCase()}.'),
        ]),
      ),
      gap,
      Boxed(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(str(r['name']), style: display(ctx, size: 16)),
          const SizedBox(height: 8),
          contact(LucideIcons.mail, str(r['email']), 'mailto:${r['email']}'),
          contact(LucideIcons.phone, str(r['phone']), 'tel:${r['phone']}'),
        ]),
      ),
      gap,
      if (editing && isTable)
        Boxed(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TwoCol(children: [
              SmallField(
                label: 'Date',
                controller: dDate,
                readOnly: true,
                suffix: Icon(LucideIcons.calendar, size: 16, color: c.fgMuted),
                onTap: () async {
                  final v = await pickDateValue(ctx, dDate.text);
                  if (v != null) update(() => dDate.text = v);
                },
              ),
              SmallField(
                label: 'Time',
                controller: dTime,
                readOnly: true,
                suffix: Icon(LucideIcons.clock, size: 16, color: c.fgMuted),
                onTap: () async {
                  final v = await pickTimeValue(ctx, dTime.text);
                  if (v != null) update(() => dTime.text = v);
                },
              ),
              SmallField(label: 'Guests', controller: dGuests, number: true),
              SmallField(label: 'Occasion', controller: dOccasion),
            ]),
            const SizedBox(height: 12),
            SmallField(label: 'Notes / requests', controller: dRequests, maxLines: 2),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Btn('Cancel', kind: BtnKind.ghost, onPressed: () => update(() => editing = false)),
              const SizedBox(width: 8),
              Btn('Save changes', onPressed: save),
            ]),
          ]),
        )
      else
        Boxed(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rows[i].$1, style: TextStyle(fontSize: 14, color: c.fgMuted)),
                  const SizedBox(width: 24),
                  Expanded(child: Text(jsNum(rows[i].$2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                ]),
              ),
          ]),
        ),
      if (isTable && !editing && !isClosed(r)) ...[
        gap,
        Align(
          alignment: Alignment.centerLeft,
          child: LinkBtn('Edit reservation', icon: LucideIcons.pencil, color: c.accent, size: 14, weight: FontWeight.w600, onTap: startEdit),
        ),
      ],
      if (!editing) ...[
        gap,
        if (next.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Caption('Update status'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in next)
                Btn('Mark ${_statusLabels[s]}',
                    kind: s == 'CANCELED' || s == 'NO_SHOW' ? BtnKind.dangerOutline : BtnKind.primary, onPressed: () => changeStatus(str(r['id']), s)),
            ]),
          ])
        else
          Muted('This reservation is ${_statusLabels[st] ?? st} — no further actions.', size: 14),
      ],
    ]);
  }
}
