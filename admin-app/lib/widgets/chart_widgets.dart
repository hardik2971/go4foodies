import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme.dart';

/// Charts + small dashboard/analytics primitives (ports of the Chart.js / SVG widgets in the
/// Blade dashboard, table-analytics and reports views). Colours come from `context.c`, so every
/// chart follows dark mode (the Blade redrew on `theme-changed`).

// ---------------------------------------------------------------- number helpers

/// JS `String(number)` / PHP `Format::js`: integral values without ".0", no float noise.
String jsNum(dynamic v) {
  if (v == null) return '0';
  if (v is String) return v;
  final n = v as num;
  if (n.isNaN) return 'NaN';
  if (n == n.roundToDouble() && n.abs() < 1e21) return n.toInt().toString();
  final clean = double.parse(n.toStringAsFixed(10));
  return clean == clean.roundToDouble() ? clean.toInt().toString() : clean.toString();
}

/// JS Math.round (half-up).
int jsRound(num v) => (v + 0.5).floor();

double numOf(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Resolve the dashboard's `var(--color-x)` / `#hex` strings to a theme colour.
Color cssColor(BuildContext context, String? s) {
  final c = context.c;
  final m = RegExp(r'^var\(--color-([\w-]+)\)$').firstMatch((s ?? '').trim());
  if (m != null) {
    return switch (m.group(1)) {
      'success' => c.success,
      'warn' => c.warn,
      'danger' => c.danger,
      'info' => c.info,
      'accent' => c.accent,
      'gold' => c.gold,
      'fg-muted' => c.fgMuted,
      'border' => c.border,
      'brand-green' => c.brandGreen,
      _ => c.fg,
    };
  }
  final hex = (s ?? '').replaceFirst('#', '');
  if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
  return c.accent;
}

// ---------------------------------------------------------------- small primitives

/// Static header filter chip (x-ops.filter-pill) — calendar icon + label + chevron; non-functional.
class StaticFilterPill extends StatelessWidget {
  const StaticFilterPill(this.label, {super.key, this.icon = true});
  final String label;
  final bool icon;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon) ...[Icon(LucideIcons.calendar, size: 14, color: c.fgMuted), const SizedBox(width: 8)],
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.fgMuted)),
        const SizedBox(width: 8),
        Icon(LucideIcons.chevronDown, size: 14, color: c.fgMuted),
      ]),
    );
  }
}

/// 32×32 rounded-lg square button: bordered (arrow-up-right, non-functional) or plain (pencil edit).
class SquareButton extends StatefulWidget {
  const SquareButton(this.icon, {super.key, this.onPressed, this.bordered = false, this.tooltip});
  final IconData icon;
  final VoidCallback? onPressed;
  final bool bordered;
  final String? tooltip;
  @override
  State<SquareButton> createState() => _SquareButtonState();
}

class _SquareButtonState extends State<SquareButton> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final box = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: !widget.bordered && hover ? c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.bordered ? Border.all(color: hover ? c.accent.withValues(alpha: .4) : c.border) : null,
          ),
          child: Icon(widget.icon, size: 16, color: hover ? c.accent : c.fgMuted),
        ),
      ),
    );
    return widget.tooltip == null ? box : Tooltip(message: widget.tooltip!, child: box);
  }
}

/// Inline legend dot + label.
class LegendDot extends StatelessWidget {
  const LegendDot(this.color, this.label, {super.key, this.size = 10});
  final Color color;
  final String label;
  final double size;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.c.fgMuted)),
      ]);
}

/// Thin progress bar (occupancy mini bar, top-items bar).
class MiniBar extends StatelessWidget {
  const MiniBar({super.key, required this.fraction, this.width, this.height = 6, this.track, this.fill});
  final double fraction;
  final double? width;
  final double height;
  final Color? track, fill;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: track ?? c.border),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: f,
            child: DecoratedBox(decoration: BoxDecoration(color: fill ?? c.accent, borderRadius: BorderRadius.circular(999))),
          ),
        ]),
      ),
    );
  }
}

/// Chart.js-style tooltip box (surface bg, border, radius 12).
class ChartTooltipBox extends StatelessWidget {
  const ChartTooltipBox({super.key, this.title, required this.lines});
  final String? title;
  final List<(Color?, String)> lines;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border), boxShadow: c.popShadow),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(title!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.fg))),
        for (final l in lines)
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (l.$1 != null) ...[Container(width: 10, height: 10, color: l.$1), const SizedBox(width: 6)],
            Text(l.$2, style: TextStyle(fontSize: 12, color: c.fg)),
          ]),
      ]),
    );
  }
}

TextStyle _tick(BuildContext context) => TextStyle(fontSize: 11, color: context.c.fgMuted);

// ---------------------------------------------------------------- dashboard: cost vs revenue line chart

/// CostRevenueChart — two monotone lines (Sells #3a3a3a, Operational Cost accent), highlight band
/// from the first outlet to the active outlet, dashed accent hover line, pill tooltips `$xK`.
class CostRevenueChart extends StatefulWidget {
  const CostRevenueChart({super.key, required this.series, required this.activeOutlet, this.height = 260});
  final List<Map<String, dynamic>> series; // {outlet, sells, cost}
  final String activeOutlet;
  final double height;
  @override
  State<CostRevenueChart> createState() => _CostRevenueChartState();
}

class _CostRevenueChartState extends State<CostRevenueChart> {
  static const sellsColor = Color(0xFF3A3A3A);
  static const leftReserved = 44.0, bottomReserved = 26.0, topPad = 20.0, rightPad = 8.0;
  int? hoverIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = widget.series;
    final n = s.length;
    final sells = [for (final d in s) numOf(d['sells'])];
    final cost = [for (final d in s) numOf(d['cost'])];
    final dataMax = [...sells, ...cost, 15000.0].reduce(math.max);
    final maxY = (dataMax / 3000).ceil() * 3000.0;
    final activeIndex = s.indexWhere((d) => d['outlet'] == widget.activeOutlet);
    final maxX = n > 1 ? (n - 1).toDouble() : 1.0;

    String fmtK(double v) => '\$${jsRound(v / 1000)}K';

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, box) {
        final plotW = box.maxWidth - leftReserved - rightPad;
        final plotH = widget.height - bottomReserved - topPad;
        double px(int i) => leftReserved + (n > 1 ? i / maxX : 0) * plotW;
        double py(double v) => topPad + (1 - v / maxY) * plotH;

        Widget? tip;
        final hi = hoverIndex;
        if (hi != null && hi < n) {
          final caretX = px(hi);
          final caretY = (py(sells[hi]) + py(cost[hi])) / 2;
          tip = Positioned(
            left: math.min(caretX + 12, box.maxWidth - 70),
            top: math.max(0, caretY - 20),
            child: IgnorePointer(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (color, v) in [(sellsColor, sells[hi]), (c.accent, cost[hi])])
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999), boxShadow: c.popShadow),
                    child: Text(fmtK(v), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
          );
        }

        LineChartBarData line(List<double> ys, Color color) => LineChartBarData(
              spots: [for (var i = 0; i < ys.length; i++) FlSpot(i.toDouble(), ys[i])],
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            );

        return Stack(children: [
          Padding(
            padding: const EdgeInsets.only(top: topPad, right: rightPad),
            child: LineChart(
              duration: Duration.zero,
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: [
                  if (activeIndex > 0) VerticalRangeAnnotation(x1: 0, x2: activeIndex.toDouble(), color: c.accent.withValues(alpha: .06)),
                ]),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 3000,
                  getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: leftReserved,
                      interval: 3000,
                      getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text('\$${jsNum(v / 1000)}K', style: _tick(context))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: bottomReserved,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (v != i || i < 0 || i >= n) return const SizedBox();
                        return SideTitleWidget(meta: meta, child: Text('${s[i]['outlet']}', style: _tick(context)));
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 100000,
                  getTouchedSpotIndicator: (bar, idx) => [
                    for (final _ in idx)
                      TouchedSpotIndicatorData(
                        FlLine(color: c.accent, strokeWidth: 1, dashArray: [4, 4]),
                        FlDotData(getDotPainter: (spot, _, b, _) => FlDotCirclePainter(radius: 5, color: b.color ?? c.accent, strokeWidth: 0)),
                      ),
                  ],
                  getTouchLineStart: (_, _) => maxY,
                  getTouchLineEnd: (_, _) => 0,
                  touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => [for (final _ in spots) null], getTooltipColor: (_) => Colors.transparent),
                  touchCallback: (event, res) {
                    final spots = res?.lineBarSpots;
                    final idx = (!event.isInterestedForInteractions || spots == null || spots.isEmpty) ? null : spots.first.x.round();
                    if (idx != hoverIndex) setState(() => hoverIndex = idx);
                  },
                ),
                lineBarsData: [line(sells, sellsColor), line(cost, c.accent)],
              ),
            ),
          ),
          ?tip,
        ]);
      }),
    );
  }
}

// ---------------------------------------------------------------- dashboard: employee semicircle doughnut

/// EmployeeGauge — semicircle doughnut (rotation −90, 180°, cutout 70 %, rounded segments,
/// spacing 3, no tooltip). Arc sits at the bottom of a 150px box (padding top 38 / bottom 8).
class SemiDoughnut extends StatelessWidget {
  const SemiDoughnut({super.key, required this.values, required this.colors, this.height = 150});
  final List<double> values;
  final List<Color> colors;
  final double height;
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _SemiDoughnutPainter(values, colors)));
}

class _SemiDoughnutPainter extends CustomPainter {
  _SemiDoughnutPainter(this.values, this.colors);
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    const padTop = 38.0, padBottom = 8.0;
    final areaH = size.height - padTop - padBottom;
    final rOut = math.min(size.width / 2, areaH);
    final rIn = rOut * .7;
    final center = Offset(size.width / 2, size.height - padBottom);
    const spacing = 3.0;
    var start = math.pi; // left, sweeping clockwise over the top
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi;
      if (sweep > 0) {
        final path = _roundedArc(center, rIn, rOut, start, sweep, 6, spacing);
        if (path != null) canvas.drawPath(path, Paint()..color = colors[i % colors.length]);
      }
      start += sweep;
    }
  }

  /// Annular sector with rounded corners (Chart.js `borderRadius`) and a [gap] (px) between segments.
  static Path? _roundedArc(Offset c, double rIn, double rOut, double start, double sweep, double radius, double gap) {
    final gOut = gap / 2 / rOut, gIn = gap / 2 / rIn;
    final a0o = start + gOut, a1o = start + sweep - gOut;
    final a0i = start + gIn, a1i = start + sweep - gIn;
    if (a1o <= a0o || a1i <= a0i) return null;
    final thick = rOut - rIn;
    final cr = math.min(radius, math.min(thick / 2, (a1o - a0o) * rOut / 2));
    Offset p(double r, double a) => c + Offset(r * math.cos(a), r * math.sin(a));
    final dOut = cr / rOut, dIn = cr / rIn;
    final path = Path()..moveTo(p(rOut - cr, a0o).dx, p(rOut - cr, a0o).dy);
    path.arcToPoint(p(rOut, a0o + dOut), radius: Radius.circular(cr));
    path.arcTo(Rect.fromCircle(center: c, radius: rOut), a0o + dOut, (a1o - dOut) - (a0o + dOut), false);
    path.arcToPoint(p(rOut - cr, a1o), radius: Radius.circular(cr));
    path.lineTo(p(rIn + cr, a1i).dx, p(rIn + cr, a1i).dy);
    path.arcToPoint(p(rIn, a1i - dIn), radius: Radius.circular(cr));
    path.arcTo(Rect.fromCircle(center: c, radius: rIn), a1i - dIn, (a0i + dIn) - (a1i - dIn), false);
    path.arcToPoint(p(rIn + cr, a0i), radius: Radius.circular(cr));
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_SemiDoughnutPainter old) => old.values != values || old.colors != colors;
}

// ---------------------------------------------------------------- dashboard: POS ticked gauge

/// PaymentGauge — SVG ticked semicircle (viewBox 240×132, 48 ticks lerped green→orange,
/// ticks above value+4 dimmed #e6e8ec), centre `{value}%` + caption.
class TickGauge extends StatelessWidget {
  const TickGauge({super.key, required this.value, required this.label, this.caption = 'Cash Payment'});
  final double value;
  final String label;
  final String caption;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AspectRatio(
      aspectRatio: 240 / 132,
      child: FittedBox(
        child: SizedBox(
          width: 240,
          height: 132,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _TickGaugePainter(value))),
            Positioned(
              left: 0,
              right: 0,
              top: 72,
              child: Text(label, textAlign: TextAlign.center, style: display(context, size: 30).copyWith(height: 1)),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 110,
              child: Text(caption, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.fgMuted, height: 1)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TickGaugePainter extends CustomPainter {
  _TickGaugePainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    const cx = 120.0, cy = 118.0, rIn = 84.0, rOut = 108.0, ticks = 48;
    const a = [22, 163, 74], b = [241, 90, 36];
    for (var i = 0; i < ticks; i++) {
      final t = i / (ticks - 1);
      final rad = (180 - t * 180) * math.pi / 180;
      final dim = t * 100 > value + 4;
      final color = dim
          ? const Color(0xFFE6E8EC)
          : Color.fromARGB(255, jsRound(a[0] + (b[0] - a[0]) * t), jsRound(a[1] + (b[1] - a[1]) * t), jsRound(a[2] + (b[2] - a[2]) * t));
      canvas.drawLine(
        Offset(cx + rIn * math.cos(rad), cy - rIn * math.sin(rad)),
        Offset(cx + rOut * math.cos(rad), cy - rOut * math.sin(rad)),
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TickGaugePainter old) => old.value != value;
}

// ---------------------------------------------------------------- dashboard: segmented bar

/// Sales-type bar: flex row, gap 6px, 10px tall rounded segments with widths = percent.
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.percents, required this.colors});
  final List<double> percents;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    final sum = percents.fold<double>(0, (a, b) => a + b);
    final children = <Widget>[];
    for (var i = 0; i < percents.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 6));
      final f = (percents[i] * 10).round();
      children.add(f <= 0
          ? const SizedBox(height: 10)
          : Expanded(
              flex: f,
              child: Container(height: 10, decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(999))),
            ));
    }
    final rest = ((100 - sum) * 10).round();
    if (rest > 0) children.add(Spacer(flex: rest));
    return Row(children: children);
  }
}

// ---------------------------------------------------------------- vertical bar chart (busy hours, revenue by outlet)

/// Accent bars with rounded tops (6px), horizontal grid lines, fixed Y axis (max/step),
/// Chart.js-like tooltip box.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.maxY,
    required this.step,
    required this.tooltip,
    this.height = 256,
    this.yLabel,
    this.xLabel,
    this.barFraction,
    this.leftReserved = 40,
    this.dashedGrid = false,
  });
  final List<String> labels;
  final List<double> values;
  final double maxY, step, height, leftReserved;
  final String Function(double v)? yLabel;
  final String Function(String label)? xLabel;

  /// (title, line) shown on hover of bar i.
  final (String?, String) Function(int i) tooltip;

  /// Bar width as a fraction of the category width (Chart.js barPercentage·categoryPercentage).
  final double? barFraction;
  final bool dashedGrid;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, box) {
        final n = math.max(1, labels.length);
        final catW = (box.maxWidth - leftReserved - 8) / n;
        final barW = catW * (barFraction ?? .72);
        return Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: BarChart(
            duration: Duration.zero,
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 0,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1, dashArray: dashedGrid ? [3, 3] : null),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: leftReserved,
                    interval: step,
                    getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(yLabel?.call(v) ?? jsNum(v), style: _tick(context))),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) return const SizedBox();
                      return SideTitleWidget(meta: meta, child: Text(xLabel?.call(labels[i]) ?? labels[i], style: _tick(context)));
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => c.surface,
                  tooltipBorder: BorderSide(color: c.border),
                  tooltipBorderRadius: BorderRadius.circular(12),
                  tooltipPadding: const EdgeInsets.all(10),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, gi, rod, ri) {
                    final (title, line) = tooltip(group.x);
                    return BarTooltipItem(
                      title == null ? line : '$title\n',
                      TextStyle(fontSize: 12, color: c.fg, fontWeight: title == null ? FontWeight.w400 : FontWeight.w700),
                      textAlign: TextAlign.left,
                      children: title == null ? null : [TextSpan(text: line, style: TextStyle(fontSize: 12, color: c.fg, fontWeight: FontWeight.w400))],
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: values[i],
                      width: barW,
                      color: c.accent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ]),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------- reports: category doughnut

/// CategoryPie — doughnut radius 90 / cutout 55, spacing 2, hover tooltip "Category : $x".
/// Slices drawn reversed from 3 o'clock clockwise (matches the recharts orientation the Blade copied).
class CategoryDonut extends StatefulWidget {
  const CategoryDonut({super.key, required this.labels, required this.values, required this.colors, this.height = 220, this.tooltip});
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final double height;
  final String Function(int i)? tooltip;
  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  int? hover;
  Offset? pos;

  @override
  Widget build(BuildContext context) {
    final n = widget.values.length;
    // reversed order (index r ↔ original n-1-r)
    final sections = <PieChartSectionData>[
      for (var r = 0; r < n; r++)
        PieChartSectionData(
          value: widget.values[n - 1 - r],
          color: widget.colors[n - 1 - r],
          radius: 35,
          showTitle: false,
        ),
    ];
    final h = hover;
    return SizedBox(
      height: widget.height,
      child: Stack(clipBehavior: Clip.none, children: [
        if (n > 0 && widget.values.any((v) => v > 0))
          Positioned.fill(
            child: PieChart(
              duration: Duration.zero,
              PieChartData(
                sections: sections,
                centerSpaceRadius: 55,
                sectionsSpace: 2,
                startDegreeOffset: 0,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(touchCallback: (event, res) {
                  final idx = res?.touchedSection?.touchedSectionIndex;
                  final orig = (!event.isInterestedForInteractions || idx == null || idx < 0) ? null : n - 1 - idx;
                  setState(() {
                    hover = orig;
                    pos = res?.touchLocation;
                  });
                }),
              ),
            ),
          ),
        if (h != null && pos != null && h < n)
          Positioned(
            left: pos!.dx + 12,
            top: pos!.dy - 16,
            child: IgnorePointer(
              child: ChartTooltipBox(lines: [(widget.colors[h], widget.tooltip?.call(h) ?? '${widget.labels[h]} : ${widget.values[h]}')]),
            ),
          ),
      ]),
    );
  }
}
