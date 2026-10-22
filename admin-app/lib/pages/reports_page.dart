import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/ui.dart';

/// Reports — port of reports/index.blade.php (GET /reports; all-time, no date filter).
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from((await Api.get('/reports') as Map)['data'] as Map),
        builder: (context, data, _) => _Reports(data: data),
      );
}

const _pieColors = [Color(0xFFE2470F), Color(0xFFF5761E), Color(0xFF0B5E46), Color(0xFF3B82F6), Color(0xFF9A6CF1), Color(0xFF16A34A), Color(0xFFEF4444)];

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? [for (final e in v) _m(e)] : const [];

/// `$${Number(v).toLocaleString()}`
String _usd(num v) => '\$${grouped(v)}';

class _Reports extends StatelessWidget {
  const _Reports({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lg = MediaQuery.sizeOf(context).width >= 1024;
    final summary = _m(data['summary']);
    final byOutlet = _l(data['revenueByOutlet']);
    final topItems = _l(data['topItems']);
    final categoryMix = _l(data['categoryMix']);
    final orderTypes = _l(data['orderTypes']);
    final paymentMix = _l(data['paymentMix']);
    final maxQty = math.max(1.0, topItems.fold<double>(1, (m, t) => math.max(m, numOf(t['qty']))));
    final catTotal = categoryMix.fold<double>(0, (s, x) => s + numOf(x['revenue']));
    const gap = SizedBox(height: 20, width: 20);

    void downloadTopItems() {
      if (topItems.isEmpty) return;
      downloadCsv('top-items.csv', [
        ['Item', 'Quantity', 'Revenue'],
        for (final t in topItems) [t['name'] ?? '', jsNum(t['qty'] ?? 0), jsNum(t['revenue'] ?? 0)],
      ]);
    }

    Widget split(Widget a, Widget b) => lg
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: a), gap, Expanded(flex: 5, child: b)])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, gap, b]);

    final revenues = [for (final d in byOutlet) numOf(d['revenue'])];
    final axis = niceAxis(revenues.fold<double>(0, math.max));

    final revenueCard = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Revenue by Outlet', style: display(context, size: 18)),
        const SizedBox(height: 16),
        SimpleBarChart(
          height: 260,
          labels: [for (final d in byOutlet) '${d['outlet'] ?? ''}'],
          values: revenues,
          maxY: axis.max,
          step: axis.step,
          barFraction: .8,
          leftReserved: 56,
          xLabel: (l) => l.replaceFirst('Outlet ', 'O'),
          yLabel: (v) => '\$${jsNum(v)}',
          tooltip: (i) => ('${byOutlet[i]['outlet']}', 'Revenue : ${_usd(revenues[i])}'),
        ),
      ]),
    );

    final categoryCard = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Category Mix', style: display(context, size: 18)),
        const SizedBox(height: 16),
        CategoryDonut(
          labels: [for (final d in categoryMix) '${d['category'] ?? ''}'],
          values: [for (final d in categoryMix) numOf(d['revenue'])],
          colors: [for (var i = 0; i < categoryMix.length; i++) _pieColors[i % _pieColors.length]],
          tooltip: (i) => '${categoryMix[i]['category']} : ${_usd(numOf(categoryMix[i]['revenue']))}',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < categoryMix.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _pieColors[i % _pieColors.length], shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text('${categoryMix[i]['category'] ?? ''}', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
              Text(
                '${money(numOf(categoryMix[i]['revenue']))} · ${catTotal != 0 ? jsRound(numOf(categoryMix[i]['revenue']) / catTotal * 100) : 0}%',
                style: TextStyle(fontSize: 14, color: c.fgMuted),
              ),
            ]),
          ),
      ]),
    );

    final topCard = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Top Selling Items', style: display(context, size: 18)),
        const SizedBox(height: 16),
        for (final t in topItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('${t['name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                Text('${jsNum(t['qty'] ?? 0)} sold · ${money(numOf(t['revenue']))}', style: TextStyle(fontSize: 14, color: c.fgMuted)),
              ]),
              const SizedBox(height: 6),
              MiniBar(fraction: numOf(t['qty']) / maxQty, height: 8, track: c.bg),
            ]),
          ),
      ]),
    );

    Widget countList(String title, List<Map<String, dynamic>> rows, String key) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: display(context, size: 18)),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: Text('${r[key] ?? ''}', style: const TextStyle(fontSize: 14))),
                Text('${r['count'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
        ]);

    final typesCard = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        countList('Order Types', orderTypes, 'type'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
          child: countList('Payment Methods', paymentMix, 'method'),
        ),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerRight,
        child: Btn('Export top items (CSV)', icon: LucideIcons.download, kind: BtnKind.ghost, onPressed: downloadTopItems),
      ),
      gap,
      LayoutBuilder(builder: (context, box) {
        final cols = lg ? 4 : 2;
        final cw = (box.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final t in [
            StatTile(icon: LucideIcons.dollarSign, label: 'Revenue', value: money(numOf(summary['revenue']))),
            StatTile(icon: LucideIcons.shoppingBag, label: 'Orders', value: '${summary['orders'] ?? 0}'),
            StatTile(icon: LucideIcons.boxes, label: 'Items Sold', value: '${summary['itemsSold'] ?? 0}'),
            StatTile(icon: LucideIcons.receipt, label: 'Avg Order', value: money(numOf(summary['avgOrder']))),
          ])
            SizedBox(width: cw, child: t),
        ]);
      }),
      gap,
      split(revenueCard, categoryCard),
      gap,
      split(topCard, typesCard),
    ]);
  }
}
