import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/ui.dart';

/// Table History — port of table-analytics/history.blade.php (GET /table-history/{tableId}?days=).
class TableHistoryPage extends StatelessWidget {
  const TableHistoryPage({super.key, required this.tableId, required this.days});
  final String tableId;
  final int days;

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        key: ValueKey('$tableId/$days'),
        load: () async => Map<String, dynamic>.from(await Api.get('/table-history/${Uri.encodeComponent(tableId)}', query: {'days': '$days'}) as Map),
        builder: (context, res, _) {
          final data = _m(res['data']);
          final table = data['table'];
          if (table is! Map) return Text('Table not found.', style: TextStyle(fontSize: 14, color: context.c.fgMuted));
          return _History(table: _m(table), sessions: _l(data['sessions']), days: (res['days'] as num?)?.toInt() ?? days);
        },
      );
}

const _periods = [(1, 'Today'), (7, 'Last 7 Days'), (30, 'Last 30 Days')];

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? [for (final e in v) _m(e)] : const [];

/// `new Date(x).toLocaleTimeString()` (en-US): "3:07:05 PM".
String _localeTime(dynamic v) {
  final d = parseDate(v);
  return d == null ? '' : DateFormat('h:mm:ss a', 'en_US').format(d);
}

class _History extends StatelessWidget {
  const _History({required this.table, required this.sessions, required this.days});
  final Map<String, dynamic> table;
  final List<Map<String, dynamic>> sessions;
  final int days;

  void _exportCsv() {
    const header = ['Date', 'Opened', 'Closed', 'Duration(min)', 'Guests', 'Waiter', 'Items', 'Subtotal', 'Discount', 'Tax', 'Service', 'Tip', 'Total', 'Payment', 'Status'];
    final rows = [
      for (final s in sessions)
        [
          '${s['openedAt'] ?? ''}'.length >= 10 ? '${s['openedAt']}'.substring(0, 10) : '${s['openedAt'] ?? ''}',
          _localeTime(s['openedAt']),
          s['closedAt'] != null ? _localeTime(s['closedAt']) : '',
          jsNum(s['durationMinutes'] ?? 0),
          jsNum(s['customerCount'] ?? 0),
          s['waiterName'] ?? '',
          _l(s['items']).map((i) => '${jsNum(i['qty'] ?? 0)}x ${i['name']}').join('; '),
          for (final k in ['subtotal', 'discount', 'tax', 'serviceCharge', 'tip', 'total']) jsNum(s[k] ?? 0),
          s['paymentMethod'] ?? '',
          s['status'] ?? '',
        ],
    ];
    downloadCsv('table-${table['number']}-history.csv', [header, ...rows]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    var revenue = 0.0, guests = 0.0, mins = 0.0;
    for (final s in sessions) {
      revenue += numOf(s['total']);
      guests += numOf(s['customerCount']);
      mins += numOf(s['durationMinutes']);
    }
    final name = '${table['name'] ?? ''}';
    const gap = SizedBox(height: 20);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        _BackLink(onTap: () => context.go('/table-analytics')),
        Btn('Export CSV', icon: LucideIcons.download, kind: BtnKind.ghost, onPressed: _exportCsv),
      ]),
      gap,
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Table ${table['number'] ?? ''}', style: display(context, size: 20)),
            if (name.isNotEmpty) TextSpan(text: ' · $name', style: TextStyle(fontSize: 14, color: c.fgMuted)),
          ])),
          const SizedBox(height: 12),
          Wrap(spacing: 32, runSpacing: 8, children: [
            for (final t in ['${sessions.length} sessions', '${jsNum(guests)} guests', '${money(revenue)} revenue', '${jsNum(mins)} min total occupied'])
              Text(t, style: TextStyle(fontSize: 14, color: c.fgMuted)),
          ]),
          const SizedBox(height: 16),
          FilterPills<int>(
            options: [for (final p in _periods) p.$1],
            value: days,
            label: (d) => _periods.firstWhere((p) => p.$1 == d).$2,
            onChanged: (d) => context.go('/table-history/${Uri.encodeComponent('${table['id']}')}?days=$d'),
          ),
        ]),
      ),
      gap,
      if (sessions.isEmpty)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 64),
          child: Center(child: Text('No sessions in this period.', style: TextStyle(fontSize: 14, color: c.fgMuted))),
        )
      else
        Container(
          margin: const EdgeInsets.only(left: 10),
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: c.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < sessions.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 16), child: _SessionItem(sessions[i])),
          ]),
        ),
    ]);
  }
}

class _BackLink extends StatefulWidget {
  const _BackLink({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_BackLink> createState() => _BackLinkState();
}

class _BackLinkState extends State<_BackLink> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final color = hover ? context.c.accent : context.c.fgMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.arrowLeft, size: 16, color: color),
          const SizedBox(width: 8),
          Text('Analytics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
        ]),
      ),
    );
  }
}

class _SessionItem extends StatelessWidget {
  const _SessionItem(this.s);
  final Map<String, dynamic> s;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final open = s['status'] == 'OPEN';
    final closedAt = s['closedAt'];
    final when = fmtDate(s['openedAt'], 'EEE, MMM d · h:mm a') + (closedAt != null && closedAt != '' ? ' – ${fmtDate(closedAt, 'h:mm a')}' : ' (open)');
    final items = _l(s['items']);
    final waiter = '${s['waiterName'] ?? ''}';
    final pay = '${s['paymentMethod'] ?? ''}';
    final discount = numOf(s['discount']), tax = numOf(s['tax']), svc = numOf(s['serviceCharge']), tip = numOf(s['tip']);
    final adjustments = discount > 0 || tax > 0 || svc > 0 || tip > 0;
    final meta = TextStyle(fontSize: 12, color: c.fgMuted);
    Widget iconMeta(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: c.fgMuted), const SizedBox(width: 6), Text(t, style: meta)]);

    return Stack(clipBehavior: Clip.none, children: [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
            Text(when, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text(money(numOf(s['total'])), style: display(context, size: 18)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 20, runSpacing: 4, children: [
            iconMeta(LucideIcons.users, '${jsNum(s['customerCount'] ?? 0)} guests'),
            iconMeta(LucideIcons.clock, '${jsNum(s['durationMinutes'] ?? 0)} min'),
            if (waiter.isNotEmpty) iconMeta(LucideIcons.userRound, waiter),
            if (pay.isNotEmpty) Text('Paid · $pay', style: meta),
          ]),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 4, children: [
              for (final it in items)
                Text.rich(TextSpan(style: TextStyle(fontSize: 14, color: c.fgMuted), children: [
                  TextSpan(text: '${jsNum(it['qty'] ?? 0)}×', style: TextStyle(fontWeight: FontWeight.w500, color: c.fg)),
                  TextSpan(text: ' ${it['name'] ?? ''}'),
                ])),
            ]),
          ],
          if (adjustments) ...[
            const SizedBox(height: 8),
            Text(
              'Subtotal ${money(numOf(s['subtotal']))}'
              '${discount > 0 ? ' · −${money(discount)} disc' : ''}'
              '${tax > 0 ? ' · +${money(tax)} tax' : ''}'
              '${svc > 0 ? ' · +${money(svc)} svc' : ''}'
              '${tip > 0 ? ' · +${money(tip)} tip' : ''}',
              style: meta,
            ),
          ],
        ]),
      ),
      // timeline dot (12px, 4px surface ring) centred on the left rail
      Positioned(
        left: -24 - 10.5,
        top: 2,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Container(width: 12, height: 12, decoration: BoxDecoration(color: open ? c.danger : c.accent, shape: BoxShape.circle)),
        ),
      ),
    ]);
  }
}
