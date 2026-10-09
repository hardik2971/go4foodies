import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../staff/staff_providers.dart';

/// Reports (admin /reports + /table-analytics + /transactions) in tabs.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(tabs: [Tab(text: 'Sales'), Tab(text: 'Tables'), Tab(text: 'Transactions')]),
        ),
        body: const TabBarView(children: [_SalesTab(), _TablesTab(), _TransactionsTab()]),
      ),
    );
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<Json>(
      value: ref.watch(reportsProvider),
      onRefresh: () async => ref.refresh(reportsProvider.future),
      builder: (r) {
        final s = (r['summary'] as Json?) ?? const {};
        final top = ((r['topItems'] as List?) ?? const []).cast<Json>();
        final mix = ((r['categoryMix'] as List?) ?? const []).cast<Json>();
        final types = ((r['orderTypes'] as List?) ?? const []).cast<Json>();
        final pay = ((r['paymentMix'] as List?) ?? const []).cast<Json>();
        final byOutlet = ((r['revenueByOutlet'] as List?) ?? const []).cast<Json>();
        final maxRev = top.fold<num>(1, (m, i) => asNum(i['revenue']) > m ? asNum(i['revenue']) : m);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              KpiTile(label: 'Revenue', value: money(asNum(s['revenue'])), icon: Icons.payments_outlined, highlight: true),
              KpiTile(label: 'Orders', value: '${s['orders'] ?? 0}', icon: Icons.receipt_long_outlined),
              KpiTile(label: 'Items sold', value: '${s['itemsSold'] ?? 0}', icon: Icons.restaurant_rounded),
              KpiTile(label: 'Avg order', value: money(asNum(s['avgOrder'])), icon: Icons.trending_up_rounded),
            ],
          ),
          if (top.isNotEmpty) ...[
            const SectionTitle('Best sellers', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
            AppCard(
              child: Column(children: [
                for (final i in top.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(i['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text('${i['qty']} sold · ${money(asNum(i['revenue']))}', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: asNum(i['revenue']) / maxRev, minHeight: 6, backgroundColor: context.c.surface2),
                      ),
                    ]),
                  ),
              ]),
            ),
          ],
          if (mix.isNotEmpty) ...[
            const SectionTitle('Category mix', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
            AppCard(child: Column(children: [for (final m in mix) KeyValue('${m['category']} · ${m['qty']} items', money(asNum(m['revenue'])))])),
          ],
          if (byOutlet.isNotEmpty) ...[
            const SectionTitle('Revenue by outlet', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
            AppCard(child: Column(children: [for (final o in byOutlet) KeyValue('${o['outlet']} · ${o['orders']} orders', money(asNum(o['revenue'])))])),
          ],
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _MiniPie(title: 'Order types', rows: types, labelKey: 'type')),
            const SizedBox(width: 10),
            Expanded(child: _MiniPie(title: 'Payments', rows: pay, labelKey: 'method')),
          ]),
        ]);
      },
    );
  }
}

class _MiniPie extends StatelessWidget {
  const _MiniPie({required this.title, required this.rows, required this.labelKey});
  final String title, labelKey;
  final List<Json> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colors = [AppColors.goldBrand, c.info, c.success, c.warn, c.danger, c.muted];
    final total = rows.fold<num>(0, (s, r) => s + asNum(r['count']));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(title, padding: const EdgeInsets.fromLTRB(4, 22, 4, 10)),
      AppCard(
        child: Column(children: [
          SizedBox(
            height: 110,
            child: total == 0
                ? Center(child: Text('No data', style: TextStyle(color: c.muted)))
                : PieChart(PieChartData(centerSpaceRadius: 26, sectionsSpace: 2, sections: [
                    for (var i = 0; i < rows.length; i++)
                      PieChartSectionData(value: asNum(rows[i]['count']).toDouble(), color: colors[i % colors.length], radius: 22, showTitle: false),
                  ])),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                CircleAvatar(radius: 4, backgroundColor: colors[i % colors.length]),
                const SizedBox(width: 6),
                Expanded(child: Text(humanize('${rows[i][labelKey]}'), overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12))),
                Text('${rows[i]['count']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _TablesTab extends ConsumerStatefulWidget {
  const _TablesTab();
  @override
  ConsumerState<_TablesTab> createState() => _TablesTabState();
}

class _TablesTabState extends ConsumerState<_TablesTab> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AsyncBody<Json>(
      value: ref.watch(tableAnalyticsProvider(_days)),
      onRefresh: () async => ref.refresh(tableAnalyticsProvider(_days).future),
      builder: (a) {
        final s = (a['summary'] as Json?) ?? const {};
        final per = ((a['perTable'] as List?) ?? const []).cast<Json>();
        final hours = ((a['busyHours'] as List?) ?? const []).cast<Json>();
        final fav = ((((a['customer'] as Json?) ?? const {})['favouriteItems'] as List?) ?? const []).cast<Json>();
        final maxH = hours.fold<num>(1, (m, h) => asNum(h['sessions']) > m ? asNum(h['sessions']) : m);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 1, label: Text('Today')), ButtonSegment(value: 7, label: Text('7 days')), ButtonSegment(value: 30, label: Text('30 days'))],
            selected: {_days},
            onSelectionChanged: (v) => setState(() => _days = v.first),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              KpiTile(label: 'Table revenue', value: money(asNum(s['revenue'])), icon: Icons.payments_outlined, highlight: true),
              KpiTile(label: 'Sessions', value: '${s['sessions'] ?? 0}', icon: Icons.table_restaurant_outlined),
              KpiTile(label: 'Avg bill', value: money(asNum(s['avgBill'])), icon: Icons.receipt_outlined),
              KpiTile(label: 'Avg dining', value: '${asNum(s['avgDiningMinutes']).round()} min', icon: Icons.timer_outlined),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Row(children: [
              Expanded(child: KeyValue('Peak hour', '${a['peakHour'] ?? '—'}')),
              const SizedBox(width: 16),
              Expanded(child: KeyValue('Peak day', '${a['peakDay'] ?? '—'}')),
            ]),
          ),
          if (hours.isNotEmpty) ...[
            const SectionTitle('Busy hours', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
            AppCard(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: SizedBox(
                height: 150,
                child: BarChart(BarChartData(
                  maxY: maxH.toDouble() * 1.15,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final h = hours[v.toInt()]['hour'] as num;
                          return h % 3 == 0 ? Text('${h > 12 ? h - 12 : h}${h >= 12 ? 'p' : 'a'}', style: TextStyle(color: c.muted, fontSize: 10)) : const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < hours.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: asNum(hours[i]['sessions']).toDouble(), color: AppColors.goldBrand, width: 10, borderRadius: BorderRadius.circular(3)),
                      ]),
                  ],
                )),
              ),
            ),
          ],
          if (per.isNotEmpty) ...[
            const SectionTitle('Per table', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
            for (final t in per)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    SizedBox(width: 48, child: Text('T${t['number']}', style: display(context, size: 18))),
                    Expanded(
                      child: Text('${t['sessions']} sessions · ${t['customers']} guests · ${t['occupancyPct']}% occ.', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ),
                    Text(money(asNum(t['revenue'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
          ],
          if (fav.isNotEmpty) ...[
            const SectionTitle('Favourite dishes', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
            AppCard(child: Column(children: [for (final f in fav) KeyValue('${f['name']}', '${f['qty']} ordered')])),
          ],
        ]);
      },
    );
  }
}

class _TransactionsTab extends ConsumerWidget {
  const _TransactionsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<List<Json>>(
      value: ref.watch(transactionsProvider),
      onRefresh: () async => ref.refresh(transactionsProvider.future),
      builder: (list) => list.isEmpty
          ? ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions')])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = list[i];
                final icon = switch (t['source']) {
                  'Gift Card' => Icons.card_giftcard_rounded,
                  'Table' => Icons.table_restaurant_rounded,
                  _ => Icons.receipt_long_rounded,
                };
                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Icon(icon, color: context.c.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${t['reference']} · ${t['customer']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${t['source']} · ${t['method']} · ${fmtDateTime(t['date'])}', style: TextStyle(color: context.c.muted, fontSize: 12)),
                      ]),
                    ),
                    Text(money(asNum(t['amount'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                );
              },
            ),
    );
  }
}
