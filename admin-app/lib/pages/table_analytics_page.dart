import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/ui.dart';

/// Table Analytics — port of table-analytics/index.blade.php (GET /table-analytics?days=1|7|30).
class TableAnalyticsPage extends StatelessWidget {
  const TableAnalyticsPage({super.key, required this.days});
  final int days;

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        key: ValueKey(days),
        load: () async {
          final res = await Api.get('/table-analytics', query: {'days': '$days'});
          return Map<String, dynamic>.from((res as Map)['data'] as Map);
        },
        builder: (context, data, _) => _Analytics(data: data),
      );
}

const _periods = [(1, 'Today'), (7, 'Last 7 Days'), (30, 'Last 30 Days')];

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? [for (final e in v) _m(e)] : const [];

const _header = ['Table', 'Name', 'Sessions', 'Customers', 'Orders', 'Revenue', 'AvgBill', 'AvgDiningMin', 'OccupancyPct', 'UtilizationPct'];

List<String> _row(Map<String, dynamic> t) => [
      '${t['number'] ?? ''}',
      '${t['name'] ?? ''}',
      for (final k in ['sessions', 'customers', 'orders', 'revenue', 'avgBill', 'avgDiningMinutes', 'occupancyPct', 'utilizationPct']) jsNum(t[k] ?? 0),
    ];

class _Analytics extends StatelessWidget {
  const _Analytics({required this.data});
  final Map<String, dynamic> data;

  List<Map<String, dynamic>> get perTable => _l(data['perTable']);

  void _exportCsv() => downloadCsv('table-performance.csv', [_header, ...perTable.map(_row)]);

  String _tableHtml() {
    final head = '<tr>${_header.map((h) => '<th>$h</th>').join()}</tr>';
    final body = perTable.map((t) => '<tr>${_row(t).map((c) => '<td>${esc(c)}</td>').join()}</tr>').join();
    return '<thead>$head</thead><tbody>$body</tbody>';
  }

  // Excel via an HTML table (.xls) — opens natively in Excel, no library needed.
  void _exportXls() {
    final html =
        '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel"><head><meta charset="utf-8"></head><body><table border="1">${_tableHtml()}</table></body></html>';
    downloadText('table-performance.xls', html, 'application/vnd.ms-excel');
  }

  void _printPdf() {
    final s = _m(data['summary']);
    printHtml('''<!doctype html><html><head><title>Table Performance</title><style>
    body{font-family:system-ui,sans-serif;padding:24px;color:#0a1c18}
    h1{font-size:20px;margin:0 0 4px} .muted{color:#666;font-size:12px;margin:0 0 16px}
    table{width:100%;border-collapse:collapse;font-size:12px} th,td{border:1px solid #ddd;padding:6px 8px;text-align:left}
    th{background:#f6f6f6}
</style></head><body>
    <h1>Go4Foodie — Table Performance</h1>
    <p class="muted">${jsNum(s['sessions'] ?? 0)} sessions · ${jsNum(s['customers'] ?? 0)} customers · \$${grouped(numOf(s['revenue']))} revenue</p>
    <table>${_tableHtml()}</table>
    <script>window.onload=function(){window.print()}</script>
</body></html>''', width: 900, height: 700);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = MediaQuery.sizeOf(context).width;
    final lg = w >= 1024;
    final days = (data['days'] as num?)?.toInt() ?? 1;
    final live = _m(data['live']);
    final s = _m(data['summary']);
    final cust = _m(data['customer']);
    const gap = SizedBox(height: 20, width: 20);

    final liveItems = [
      ('Total', live['total'], c.fg),
      ('Available', live['available'], c.success),
      ('Occupied', live['occupied'], c.danger),
      ('Reserved', live['reserved'], c.warn),
      ('Cleaning', live['cleaning'], c.info),
      ('Out of Service', live['outOfService'], c.fgMuted),
    ];
    final summary = [
      ('Table Sessions', jsNum(s['sessions'] ?? 0)),
      ('Customers', jsNum(s['customers'] ?? 0)),
      ('Orders', jsNum(s['orders'] ?? 0)),
      ('Revenue', money(numOf(s['revenue']))),
      ('Avg Bill', money(numOf(s['avgBill']))),
      ('Avg Guests/Table', jsNum(s['avgCustomersPerTable'] ?? 0)),
      ('Avg Dining', '${jsNum(s['avgDiningMinutes'] ?? 0)} min'),
    ];
    final summaryCols = w >= 1280 ? 7 : (w >= 768 ? 4 : 2);

    final busy = _BusyHoursCard(data: data);
    final perf = Column(children: [
      _RankCard(
        icon: LucideIcons.trophy,
        iconColor: c.gold,
        title: 'Top Tables',
        values: _m(data['top']),
        labels: const {
          'highestRevenue': 'Highest Revenue',
          'mostUsed': 'Most Used',
          'mostCustomers': 'Most Customers',
          'highestAvgBill': 'Highest Avg Bill',
          'longestOccupied': 'Longest Occupied',
          'fastestTurnover': 'Fastest Turnover',
        },
      ),
      gap,
      _RankCard(
        icon: LucideIcons.trendingDown,
        iconColor: c.fgMuted,
        title: 'Needs Attention',
        values: _m(data['least']),
        labels: const {'leastUsed': 'Least Used', 'lowestRevenue': 'Lowest Revenue', 'lowestOccupancy': 'Lowest Occupancy'},
      ),
    ]);

    final customerCards = [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Customers', style: display(context, size: 18)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _MiniStat('Served', '${cust['served'] ?? 0}')),
            const SizedBox(width: 12),
            Expanded(child: _MiniStat('Avg Spend', money(numOf(cust['avgSpend'])))),
          ]),
        ]),
      ),
      _ListCard(
        icon: LucideIcons.star,
        iconColor: c.gold,
        title: 'Favourite Items',
        rows: [for (final f in _l(cust['favouriteItems'])) ('${f['name'] ?? ''}', '${f['qty'] ?? 0}')],
        empty: 'No data yet.',
      ),
      _ListCard(
        icon: LucideIcons.wallet,
        iconColor: c.accent,
        title: 'Payment Methods',
        rows: [for (final p in _l(cust['paymentMix'])) ('${p['method'] ?? ''}', '${p['count'] ?? 0}')],
        empty: 'No payments yet.',
      ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Period tabs + export
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        FilterPills<int>(
          options: [for (final p in _periods) p.$1],
          value: days,
          label: (d) => _periods.firstWhere((p) => p.$1 == d).$2,
          onChanged: (d) => context.go('/table-analytics?days=$d'),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Export', style: TextStyle(fontSize: 12, color: c.fgMuted)),
          const SizedBox(width: 8),
          Btn('CSV', icon: LucideIcons.download, kind: BtnKind.ghost, small: true, onPressed: _exportCsv),
          const SizedBox(width: 8),
          Btn('Excel', kind: BtnKind.ghost, small: true, onPressed: _exportXls),
          const SizedBox(width: 8),
          Btn('PDF', kind: BtnKind.ghost, small: true, onPressed: _printPdf),
        ]),
      ]),
      gap,
      // Live stats
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 32, runSpacing: 12, children: [
          for (final (label, value, tone) in liveItems)
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${value ?? 0}', style: display(context, size: 24, color: tone)),
              Text(label, style: TextStyle(fontSize: 12, color: c.fgMuted)),
            ]),
        ]),
      ),
      gap,
      // Summary
      LayoutBuilder(builder: (context, box) {
        final cw = (box.maxWidth - 16 * (summaryCols - 1)) / summaryCols;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final (label, value) in summary)
            SizedBox(
              width: cw,
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontSize: 12, color: c.fgMuted), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value, style: display(context, size: 20), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
        ]);
      }),
      gap,
      if (lg)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 8, child: busy), gap, Expanded(flex: 4, child: perf)])
      else ...[busy, gap, perf],
      gap,
      if (lg)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < customerCards.length; i++) ...[if (i > 0) gap, Expanded(child: customerCards[i])],
          ]),
        )
      else
        for (var i = 0; i < customerCards.length; i++) ...[if (i > 0) gap, customerCards[i]],
      gap,
      // Per-table performance
      DataTableCard(
        columns: const [
          DataCol('Table', flex: 3),
          DataCol('Sessions'),
          DataCol('Customers'),
          DataCol('Orders'),
          DataCol('Revenue'),
          DataCol('Avg Bill'),
          DataCol('Avg Dining'),
          DataCol('Occupancy', flex: 2),
          DataCol('Utilization'),
        ],
        empty: 'No tables yet.',
        rows: [
          for (final t in perTable)
            [
              _TableLink(t),
              Muted('${t['sessions'] ?? 0}', size: 14),
              Muted('${t['customers'] ?? 0}', size: 14),
              Muted('${t['orders'] ?? 0}', size: 14),
              Text(money(numOf(t['revenue'])), style: const TextStyle(fontWeight: FontWeight.w500)),
              Muted(money(numOf(t['avgBill'])), size: 14),
              Muted('${jsNum(t['avgDiningMinutes'] ?? 0)} min', size: 14),
              Row(mainAxisSize: MainAxisSize.min, children: [
                MiniBar(fraction: numOf(t['occupancyPct']) / 100, width: 64),
                const SizedBox(width: 8),
                Text('${jsNum(t['occupancyPct'] ?? 0)}%'),
              ]),
              Muted('${jsNum(t['utilizationPct'] ?? 0)}%', size: 14),
            ],
        ],
      ),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: context.c.bg, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.c.fgMuted)),
          const SizedBox(height: 2),
          Text(value, style: display(context, size: 20)),
        ]),
      );
}

Widget _iconTitle(BuildContext context, IconData icon, Color color, String title) => Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Flexible(child: Text(title, style: display(context, size: 18))),
    ]);

class _RankCard extends StatelessWidget {
  const _RankCard({required this.icon, required this.iconColor, required this.title, required this.values, required this.labels});
  final IconData icon;
  final Color iconColor;
  final String title;
  final Map<String, dynamic> values;
  final Map<String, String> labels;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _iconTitle(context, icon, iconColor, title),
        const SizedBox(height: 12),
        for (final e in labels.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Text(e.value, style: TextStyle(fontSize: 14, color: c.fgMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  values[e.key] is Map ? 'Table ${values[e.key]['number']} · ${values[e.key]['value']}' : '—',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.icon, required this.iconColor, required this.title, required this.rows, required this.empty});
  final IconData icon;
  final Color iconColor;
  final String title, empty;
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _iconTitle(context, icon, iconColor, title),
        const SizedBox(height: 12),
        if (rows.isEmpty) Text(empty, style: TextStyle(fontSize: 14, color: c.fgMuted)),
        for (final (a, b) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: Text(a, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
              Text(b, style: TextStyle(fontSize: 14, color: c.fgMuted)),
            ]),
          ),
      ]),
    );
  }
}

class _BusyHoursCard extends StatelessWidget {
  const _BusyHoursCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hours = _l(data['busyHours']);
    final values = [for (final b in hours) numOf(b['sessions'])];
    // recharts' default 5 integer ticks (allowDecimals=false): 0..4*step
    final peak = values.fold<double>(0, math.max);
    final step = math.max(1, (peak / 4).ceil()).toDouble();
    final yMax = peak > 0 ? step * 4 : 4.0;
    Widget meta(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 16, color: c.fgMuted),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(fontSize: 14, color: c.fgMuted)),
        ]);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Busy Hours', style: display(context, size: 18))),
          meta(LucideIcons.clock, 'Peak ${data['peakHour'] ?? '—'}'),
          const SizedBox(width: 16),
          meta(LucideIcons.calendarDays, '${data['peakDay'] ?? '—'}'),
        ]),
        const SizedBox(height: 16),
        SimpleBarChart(
          labels: [for (final b in hours) '${b['label'] ?? ''}'],
          values: values,
          maxY: yMax,
          step: step,
          height: 256,
          dashedGrid: true,
          leftReserved: 32,
          tooltip: (i) => ('${hours[i]['label']}', 'sessions: ${jsNum(values[i])}'),
        ),
      ]),
    );
  }
}

class _TableLink extends StatefulWidget {
  const _TableLink(this.t);
  final Map<String, dynamic> t;
  @override
  State<_TableLink> createState() => _TableLinkState();
}

class _TableLinkState extends State<_TableLink> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = widget.t;
    final name = '${t['name'] ?? ''}';
    final deco = hover ? TextDecoration.underline : TextDecoration.none;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: () => context.go('/table-history/${t['id']}'),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Table ${t['number'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w500, color: hover ? c.accent : c.fg, decoration: deco, decorationColor: c.accent)),
            if (name.isNotEmpty) TextSpan(text: ' · $name', style: TextStyle(fontSize: 12, color: c.fgMuted, decoration: deco, decorationColor: c.accent)),
          ]),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
