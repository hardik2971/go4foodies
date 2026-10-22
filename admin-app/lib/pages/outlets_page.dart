import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/biz_widgets.dart';
import '../widgets/ui.dart';

/// outlets/index.blade.php — read-only outlet cards + weekly revenue/cost modal.
class OutletsPage extends StatelessWidget {
  const OutletsPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: () async {
          final d = await Api.get('/outlets');
          return [for (final o in (d['outlets'] as List? ?? const [])) Map<String, dynamic>.from(o)];
        },
        builder: (context, outlets, _) => _OutletsView(outlets: outlets),
      );
}

List<Map> _weekly(Map o) => [for (final w in (o['weekly'] as List? ?? const [])) Map.from(w)];

/// outlets-data.ts current(): last weekly entry.
({num revenue, num cost}) _current(Map o) {
  final w = _weekly(o);
  if (w.isEmpty) return (revenue: 0, cost: 0);
  return (revenue: numOf(w.last['revenue']), cost: numOf(w.last['cost']));
}

int _margin(Map o) {
  final c = _current(o);
  return c.revenue == 0 ? 0 : jsRound((c.revenue - c.cost) / c.revenue * 100);
}

class _MarginPill extends StatelessWidget {
  const _MarginPill(this.margin);
  final int margin;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ok = margin >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: ok ? c.successSoft : c.dangerSoft, borderRadius: BorderRadius.circular(999)),
      child: Text('${ok ? '+' : ''}$margin% margin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ok ? c.success : c.danger)),
    );
  }
}

class _OutletsView extends StatelessWidget {
  const _OutletsView({required this.outlets});
  final List<Map<String, dynamic>> outlets;

  @override
  Widget build(BuildContext context) {
    final active = outlets.where((o) => o['isActive'] == true).length;
    final revenue = outlets.fold<num>(0, (s, o) => s + _current(o).revenue);
    final cost = outlets.fold<num>(0, (s, o) => s + _current(o).cost);
    final avgMargin = revenue != 0 ? jsRound((revenue - cost) / revenue * 100) : 0;
    final vw = MediaQuery.of(context).size.width;
    final cols = vw >= 1280 ? 3 : vw >= 640 ? 2 : 1;

    return Gap(children: [
      StatsGrid(children: [
        StatTile(icon: LucideIcons.store, label: 'Total Outlets', value: '${outlets.length}'),
        StatTile(icon: LucideIcons.circleCheck, label: 'Active', value: '$active'),
        StatTile(icon: LucideIcons.dollarSign, label: 'Weekly Revenue', value: money(revenue)),
        StatTile(icon: LucideIcons.percent, label: 'Avg Margin', value: '$avgMargin%'),
      ]),
      LayoutBuilder(builder: (context, box) {
        const gap = 16.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final o in outlets) SizedBox(width: w, child: _OutletCard(outlet: o, onTap: () => _open(context, o))),
        ]);
      }),
    ]);
  }

  void _open(BuildContext context, Map<String, dynamic> o) {
    showAppModal(context, title: '${o['name'] ?? ''}', builder: (_) => _OutletDetail(outlet: o));
  }
}

class _OutletCard extends StatefulWidget {
  const _OutletCard({required this.outlet, required this.onTap});
  final Map<String, dynamic> outlet;
  final VoidCallback onTap;
  @override
  State<_OutletCard> createState() => _OutletCardState();
}

class _OutletCardState extends State<_OutletCard> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final o = widget.outlet;
    final cur = _current(o);
    final isActive = o['isActive'] == true;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(radiusCard),
            border: Border.all(color: c.border),
            boxShadow: hover ? c.popShadow : c.cardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o['name'] ?? ''}', style: display(context, size: 18)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(LucideIcons.mapPin, size: 14, color: c.fgMuted),
                    const SizedBox(width: 4),
                    Flexible(child: Muted('${o['location'] ?? ''}', size: 12)),
                  ]),
                ]),
              ),
              ToneBadge(isActive ? 'Active' : 'Closed', tone: isActive ? Tone.success : Tone.muted),
            ]),
            const SizedBox(height: 16),
            Cols(gap: 12, [
              MiniStat(label: 'Revenue', value: money(cur.revenue)),
              MiniStat(label: 'Op. Cost', value: money(cur.cost)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Icon(LucideIcons.user, size: 14, color: c.fgMuted),
              const SizedBox(width: 6),
              Expanded(child: Muted('${o['manager'] ?? ''}', size: 12)),
              _MarginPill(_margin(o)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _OutletDetail extends StatelessWidget {
  const _OutletDetail({required this.outlet});
  final Map<String, dynamic> outlet;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final o = outlet;
    Widget row(IconData icon, String label, String value, bool first) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: c.border))),
          child: Row(children: [
            Icon(icon, size: 16, color: c.fgMuted),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, color: c.fgMuted)),
            const SizedBox(width: 12),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          ]),
        );
    Widget legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: c.fgMuted)),
        ]);

    return Gap(children: [
      Row(children: [
        Icon(LucideIcons.mapPin, size: 16, color: c.fgMuted),
        const SizedBox(width: 6),
        Expanded(child: Text('${o['location'] ?? ''}', style: TextStyle(fontSize: 14, color: c.fgMuted))),
        _MarginPill(_margin(o)),
      ]),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          row(LucideIcons.mapPin, 'Address', '${o['address'] ?? ''}', true),
          row(LucideIcons.phone, 'Phone', '${o['phone'] ?? ''}', false),
          row(LucideIcons.user, 'Manager', '${o['manager'] ?? ''}', false),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Revenue vs Operational Cost', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          legend(const Color(0xFF3A3A3A), 'Revenue'),
          const SizedBox(width: 12),
          legend(c.accent, 'Cost'),
        ]),
        const SizedBox(height: 8),
        SizedBox(height: 180, child: _WeeklyChart(weekly: _weekly(o))),
      ]),
    ]);
  }
}

/// OutletWeeklyChart.tsx — 2 monotone lines, nice Y axis `$xK`, index tooltip "Revenue : $x".
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.weekly});
  final List<Map> weekly;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (weekly.isEmpty) return const SizedBox.shrink();
    final rev = [for (final w in weekly) numOf(w['revenue']).toDouble()];
    final cost = [for (final w in weekly) numOf(w['cost']).toDouble()];
    final axis = niceAxis([0.0, ...rev, ...cost].reduce(math.max));
    final tick = TextStyle(fontSize: 11, color: c.fgMuted);
    const revColor = Color(0xFF3A3A3A);

    LineChartBarData line(List<double> ys, Color color) => LineChartBarData(
          spots: [for (var i = 0; i < ys.length; i++) FlSpot(i.toDouble(), ys[i])],
          color: color,
          barWidth: 2.5,
          isCurved: true,
          curveSmoothness: .35,
          preventCurveOverShooting: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        );

    return LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: 0,
        maxX: math.max(1, weekly.length - 1).toDouble(),
        minY: 0,
        maxY: axis.max,
        lineBarsData: [line(rev, revColor), line(cost, c.accent)],
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: axis.step,
          getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: axis.step,
              getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text('\$${jsNum(v / 1000)}K', style: tick)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= weekly.length || v != i) return const SizedBox.shrink();
                return SideTitleWidget(meta: meta, child: Text('${weekly[i]['week'] ?? ''}', style: tick));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (bar, idx) => [for (final _ in idx) const TouchedSpotIndicatorData(FlLine(color: Colors.transparent), FlDotData(show: false))],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.surface,
            tooltipBorder: BorderSide(color: c.border),
            tooltipBorderRadius: BorderRadius.circular(12),
            tooltipPadding: const EdgeInsets.all(10),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final (k, s) in spots.indexed)
                LineTooltipItem(
                  k == 0 ? '${weekly[s.x.round()]['week'] ?? ''}\n' : '',
                  TextStyle(color: c.fg, fontWeight: FontWeight.w700, fontSize: 12),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text: '${s.barIndex == 0 ? 'Revenue' : 'Cost'} : \$${grouped(s.y)}',
                      style: TextStyle(color: c.fg, fontWeight: FontWeight.w400, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
