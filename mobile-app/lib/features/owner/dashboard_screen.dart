import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../staff/staff_providers.dart';
import 'activity_screen.dart';

IconData _kpiIcon(String key) => switch (key) {
      'revenue' || 'sales' => Icons.payments_outlined,
      'orders' => Icons.receipt_long_outlined,
      'customers' => Icons.people_alt_outlined,
      _ => Icons.insights_rounded,
    };

/// Owner dashboard — the admin /dashboard, live from the same queries.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(dashboardProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(sessionProvider).profile;
    final attention = ref.watch(dashboardProvider).valueOrNull?['attention'] as num? ?? 0;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hello, ${p?.name.split(' ').first ?? ''}', style: display(context, size: 22)),
          Text(fmtDate(DateTime.now().toIso8601String(), 'EEEE, d MMMM'), style: TextStyle(color: context.c.muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Alerts',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityScreen())),
            icon: Badge(isLabelVisible: attention > 0, label: Text('$attention'), child: const Icon(Icons.notifications_none_rounded)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncBody<Json>(
        value: ref.watch(dashboardProvider),
        onRefresh: () async => ref.refresh(dashboardProvider.future),
        builder: (d) => _DashboardBody(d: d),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.d});
  final Json d;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kpis = ((d['kpis'] as List?) ?? const []).cast<Json>();
    final pos = (d['pos'] as Json?) ?? const {};
    final floor = (d['floor'] as Json?) ?? const {};
    final trending = (d['trending'] as Json?) ?? const {};
    final outlets = ((d['outletSeries'] as List?) ?? const []).cast<Json>();
    final cats = ((d['topCategories'] as List?) ?? const []).cast<Json>();
    final salesTypes = ((d['salesTypes'] as List?) ?? const []).cast<Json>();
    final recent = ((d['recentOrders'] as List?) ?? const []).cast<Json>();
    final employee = (d['employee'] as Json?) ?? const {};
    final payment = (pos['payment'] as Json?) ?? const {};

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          for (final k in kpis)
            KpiTile(label: k['label'] as String, value: '${k['value']}', delta: k['delta'] as num?, icon: _kpiIcon(k['key'] as String), highlight: k['accent'] == true),
        ],
      ),
      const SectionTitle("Today's POS", padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
      AppCard(
        child: Column(children: [
          Row(children: [
            Expanded(child: _Stat(label: 'Sales', value: '${pos['totalSales'] ?? '—'}')),
            Expanded(child: _Stat(label: 'Bills', value: '${pos['totalBills'] ?? 0}')),
            Expanded(child: _Stat(label: 'Avg bill', value: '${pos['avgValue'] ?? '—'}')),
          ]),
          const Divider(height: 26),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 18, color: c.accent),
            const SizedBox(width: 8),
            Text('Peak hour ${pos['peakHour'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          _SplitBar(parts: [
            ('Cash', asNum(payment['cash']), c.success),
            ('Card', asNum(payment['card']), c.info),
            ('Online', asNum(payment['online']), c.accent),
          ]),
        ]),
      ),
      const SectionTitle('Live floor', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
      Row(children: [
        Expanded(child: _FloorStat('Available', floor['available'], c.success)),
        const SizedBox(width: 8),
        Expanded(child: _FloorStat('Occupied', floor['occupied'], c.danger)),
        const SizedBox(width: 8),
        Expanded(child: _FloorStat('Reserved', floor['reserved'], c.warn)),
        const SizedBox(width: 8),
        Expanded(child: _FloorStat('To pay', floor['waitingPayment'], c.accent)),
      ]),
      if (outlets.isNotEmpty) ...[
        const SectionTitle('Outlets · revenue vs cost', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
          child: SizedBox(
            height: 210,
            child: BarChart(BarChartData(
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1)),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(moneyCompact(v), style: TextStyle(color: c.muted, fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${outlets[v.toInt()]['outlet']}'.replaceAll('Outlet ', 'O'),
                        style: TextStyle(color: c.muted, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < outlets.length; i++)
                  BarChartGroupData(x: i, barsSpace: 3, barRods: [
                    BarChartRodData(toY: asNum(outlets[i]['sells']).toDouble(), color: AppColors.goldBrand, width: 8, borderRadius: BorderRadius.circular(3)),
                    BarChartRodData(toY: asNum(outlets[i]['cost']).toDouble(), color: c.muted.withValues(alpha: 0.5), width: 8, borderRadius: BorderRadius.circular(3)),
                  ]),
              ],
            )),
          ),
        ),
      ],
      if (trending['name'] != null) ...[
        const SectionTitle('Trending dish', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
        AppCard(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            NetImage(trending['image'] as String? ?? '', width: 80, height: 80),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trending['name'] as String, style: display(context, size: 18)),
                Text('${trending['subtitle'] ?? ''}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.star_rounded, size: 16, color: c.gold),
                  Text(' ${asNum(trending['rating']).toStringAsFixed(1)} · ${trending['orders']} orders · ${money(asNum(trending['price']))}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ]),
              ]),
            ),
          ]),
        ),
      ],
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (salesTypes.isNotEmpty)
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Order types', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
              AppCard(
                child: Column(children: [
                  SizedBox(
                    height: 120,
                    child: PieChart(PieChartData(
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                      sections: [
                        for (var i = 0; i < salesTypes.length; i++)
                          PieChartSectionData(
                            value: asNum(salesTypes[i]['percent']).toDouble().clamp(0.01, 100),
                            color: [AppColors.goldBrand, c.info, c.success, c.warn][i % 4],
                            radius: 24,
                            showTitle: false,
                          ),
                      ],
                    )),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < salesTypes.length; i++)
                    _Legend('${salesTypes[i]['label']}', '${salesTypes[i]['percent']}%', [AppColors.goldBrand, c.info, c.success, c.warn][i % 4]),
                ]),
              ),
            ]),
          ),
        if (salesTypes.isNotEmpty && employee.isNotEmpty) const SizedBox(width: 10),
        if (employee.isNotEmpty)
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Staff', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${employee['total'] ?? 0}', style: display(context, size: 30)),
                  Text('team members', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  for (final s in ((employee['segments'] as List?) ?? const []).cast<Json>())
                    _Legend('${s['label']}', '${s['value']}', _hex(s['color'] as String?) ?? c.accent),
                ]),
              ),
            ]),
          ),
      ]),
      if (cats.isNotEmpty) ...[
        const SectionTitle('Top categories', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
        AppCard(
          child: Column(children: [
            for (final cat in cats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  NetImage(cat['image'] as String? ?? '', width: 40, height: 40, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cat['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: asNum(cat['percent']) / 100, minHeight: 6, backgroundColor: c.surface2),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Text('${cat['percent']}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
        ),
      ],
      if (recent.isNotEmpty) ...[
        const SectionTitle('Recent orders', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(children: [
            for (final o in recent)
              ListTile(
                leading: NetImage(o['image'] as String? ?? '', width: 42, height: 42, radius: 10),
                title: Text('${o['orderId']} · ${o['customer']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text('${o['type']}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(asNum(o['price'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  StatusChip(o['status'] as String),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }

  Color? _hex(String? v) {
    if (v == null || !v.startsWith('#') || v.length != 7) return null;
    return Color(int.parse('FF${v.substring(1)}', radix: 16));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(children: [
        FittedBox(child: Text(value, style: display(context, size: 20))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: context.c.muted, fontSize: 12)),
      ]);
}

class _FloorStat extends StatelessWidget {
  const _FloorStat(this.label, this.value, this.color);
  final String label;
  final Object? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Column(children: [
          Text('${value ?? 0}', style: display(context, size: 22, color: color)),
          Text(label, style: TextStyle(color: context.c.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.parts});
  final List<(String, num, Color)> parts;
  @override
  Widget build(BuildContext context) {
    final total = parts.fold<num>(0, (s, p) => s + p.$2);
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 10,
          child: total == 0
              ? Container(color: context.c.surface2)
              : Row(children: [for (final p in parts) if (p.$2 > 0) Expanded(flex: (p.$2 * 1000 ~/ total).clamp(1, 1000), child: Container(color: p.$3))]),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final p in parts)
          Row(children: [
            CircleAvatar(radius: 4, backgroundColor: p.$3),
            const SizedBox(width: 6),
            Text('${p.$1} ${p.$2}%', style: TextStyle(color: context.c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: context.c.muted, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      );
}
