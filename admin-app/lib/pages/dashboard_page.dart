import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/ui.dart';

/// Overview — port of dashboard/index.blade.php (GET /dashboard).
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.get('/dashboard') as Map),
        builder: (context, res, reload) => _Dashboard(res: res, reload: reload),
      );
}

const _kpiIcons = {'orders': LucideIcons.package, 'delivered': LucideIcons.packageCheck, 'canceled': LucideIcons.packageX, 'revenue': LucideIcons.coins};
const _orderLabels = {'PENDING': 'Pending', 'PREPARING': 'Preparing', 'READY': 'Ready', 'COMPLETED': 'Completed', 'CANCELED': 'Canceled'};

String _delta(dynamic v) => '${numOf(v) > 0 ? '+' : ''}${jsNum(v)}%';

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List ? [for (final e in v) _m(e)] : const [];

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.res, required this.reload});
  final Map<String, dynamic> res;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final xl = w >= 1280, lg = w >= 1024;
    final data = _m(res['data']);
    const gap = SizedBox(height: 20, width: 20);

    Widget split(Widget a, Widget b) => lg
        ? IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 7, child: a), gap, Expanded(flex: 5, child: b)]),
          )
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, gap, b]);

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _KpiRow(kpis: _l(data['kpis'])),
      gap,
      lg
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 7, child: _CostRevenueCard(data: data)),
              gap,
              Expanded(flex: 5, child: Column(children: [_TopCategoriesCard(res: res, reload: reload), gap, _EmployeeCard(employee: _m(data['employee']))])),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _CostRevenueCard(data: data),
              gap,
              _TopCategoriesCard(res: res, reload: reload),
              gap,
              _EmployeeCard(employee: _m(data['employee'])),
            ]),
      gap,
      split(_RecentOrdersCard(orders: _l(data['recentOrders'])), _SalesTypesCard(types: _l(data['salesTypes']), fill: lg)),
    ]);

    final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _TrendingCard(res: res, reload: reload),
      gap,
      _PosCard(pos: _m(data['pos'])),
    ]);

    if (xl) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), gap, SizedBox(width: 336, child: right)]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, gap, right]);
  }
}

// ---------------------------------------------------------------- 5.1 KPI row

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});
  final List<Map<String, dynamic>> kpis;
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1280 ? 4 : (w >= 640 ? 2 : 1);
    return LayoutBuilder(builder: (context, box) {
      final cw = (box.maxWidth - 20 * (cols - 1)) / cols;
      return Wrap(spacing: 20, runSpacing: 20, children: [for (final k in kpis) SizedBox(width: cw, child: _KpiCard(k))]);
    });
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.kpi);
  final Map<String, dynamic> kpi;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = kpi['accent'] == true;
    final up = numOf(kpi['delta']) >= 0;
    final white80 = Colors.white.withValues(alpha: .8);
    return Reveal(child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent ? c.accent : c.surface,
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: accent ? c.accent : c.border),
        boxShadow: c.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: accent ? Colors.white.withValues(alpha: .2) : c.bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(_kpiIcons[kpi['key']] ?? LucideIcons.package, size: 18, color: accent ? Colors.white : c.fgMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${kpi['label'] ?? ''}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: accent ? Colors.white.withValues(alpha: .9) : c.fgMuted)),
          ),
        ]),
        const SizedBox(height: 16),
        CountUpText('${kpi['value'] ?? ''}', style: display(context, size: 32, color: accent ? Colors.white : c.fg).copyWith(height: 1)),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent ? Colors.white.withValues(alpha: .2) : (up ? c.successSoft : c.dangerSoft),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(up ? LucideIcons.trendingUp : LucideIcons.trendingDown, size: 12, color: accent ? Colors.white : (up ? c.success : c.danger)),
              const SizedBox(width: 4),
              Text(_delta(kpi['delta']), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent ? Colors.white : (up ? c.success : c.danger))),
            ]),
          ),
          const SizedBox(width: 8),
          Text('Since last month', style: TextStyle(fontSize: 12, color: accent ? white80 : c.fgMuted)),
        ]),
      ]),
    ));
  }
}

// ---------------------------------------------------------------- shared card title

Widget _title(BuildContext context, String text) => Text(text, style: display(context, size: 18));

// ---------------------------------------------------------------- 5.2 cost vs revenue

class _CostRevenueCard extends StatelessWidget {
  const _CostRevenueCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _title(context, 'Outlets Operational Cost Vs Revenue')),
          const StaticFilterPill('Weekly'),
        ]),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, spacing: 16, runSpacing: 8, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '${data['revenueTotal'] ?? ''}', style: display(context, size: 36)),
            WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.only(left: 8), child: Text('Revenue', style: TextStyle(fontSize: 16, color: c.fgMuted)))),
          ])),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const LegendDot(Color(0xFF3A3A3A), 'Sells'),
            const SizedBox(width: 16),
            LegendDot(c.accent, 'Operational Cost'),
          ]),
        ]),
        const SizedBox(height: 12),
        CostRevenueChart(series: _l(data['outletSeries']), activeOutlet: '${data['outletActive'] ?? ''}'),
      ]),
    );
  }
}

// ---------------------------------------------------------------- 5.3 top categories

class _TopCategoriesCard extends StatelessWidget {
  const _TopCategoriesCard({required this.res, required this.reload});
  final Map<String, dynamic> res;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final cats = _l(_m(res['data'])['topCategories']);
    final editable = res['editable'] == true;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _title(context, 'Top Categories Item')),
          if (editable) SquareButton(LucideIcons.pencil, tooltip: 'Edit top categories', onPressed: () => _edit(context, cats)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: i < cats.length ? _CategoryTile(cats[i]) : const SizedBox()),
          ],
        ]),
      ]),
    );
  }

  void _edit(BuildContext context, List<Map<String, dynamic>> current) {
    final options = [for (final o in (res['categoryOptions'] as List? ?? const [])) '$o'];
    showAppModal<void>(context, title: 'Top categories', builder: (ctx) => _TopCategoriesEditor(current: current, options: options, reload: reload));
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.cat);
  final Map<String, dynamic> cat;
  @override
  Widget build(BuildContext context) {
    final img = '${cat['image'] ?? ''}';
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 96,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            if (img.isNotEmpty) Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, img, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xA6000000), Colors.transparent])),
            ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 8,
              child: Text('${cat['name'] ?? ''}',
                  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text('${jsNum(cat['percent'])}%', textAlign: TextAlign.center, style: display(context, size: 24)),
    ]);
  }
}

class _TopCategoriesEditor extends StatefulWidget {
  const _TopCategoriesEditor({required this.current, required this.options, required this.reload});
  final List<Map<String, dynamic>> current;
  final List<String> options;
  final Future<void> Function() reload;
  @override
  State<_TopCategoriesEditor> createState() => _TopCategoriesEditorState();
}

class _TopCategoriesEditorState extends State<_TopCategoriesEditor> {
  late final List<String> names;
  late final List<TextEditingController> percents;
  bool pending = false;

  @override
  void initState() {
    super.initState();
    final o = widget.options;
    String seed(int i) {
      if (i < widget.current.length && widget.current[i]['name'] != null) return '${widget.current[i]['name']}';
      if (i < o.length) return o[i];
      return o.isNotEmpty ? o.first : '';
    }

    names = [for (var i = 0; i < 3; i++) seed(i)];
    percents = [for (var i = 0; i < 3; i++) TextEditingController(text: i < widget.current.length ? jsNum(widget.current[i]['percent'] ?? 0) : '0')];
  }

  @override
  void dispose() {
    for (final p in percents) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _save(bool reset) async {
    setState(() => pending = true);
    final categories = reset
        ? null
        : [
            for (var i = 0; i < 3; i++)
              if (names[i].isNotEmpty) {'name': names[i], 'percent': num.tryParse(percents[i].text.trim()) ?? 0},
          ];
    try {
      await Api.post('/dashboard/top-categories', {'categories': categories});
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
    await widget.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Options list keeps the current name even if it is no longer a category (like the <select> did).
    List<(String, String)> items(String cur) => [
          ('', '— None —'),
          for (final o in widget.options) (o, o),
          if (cur.isNotEmpty && !widget.options.contains(cur)) (cur, cur),
        ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(children: [
            Expanded(child: AppSelect<String>(value: names[i], items: items(names[i]), width: double.infinity, onChanged: (v) => setState(() => names[i] = v))),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: TextField(controller: percents[i], keyboardType: TextInputType.number, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 4),
            Text('%', style: TextStyle(fontSize: 14, color: c.fgMuted)),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          _TextLink('Reset to auto', onTap: pending ? null : () => _save(true)),
          const Spacer(),
          Btn('Cancel', kind: BtnKind.ghost, onPressed: () => Navigator.of(context).pop()),
          const SizedBox(width: 12),
          Btn(pending ? 'Saving…' : 'Save', onPressed: pending ? null : () => _save(false)),
        ]),
      ),
    ]);
  }
}

/// Muted text button that turns accent on hover ("Reset to auto").
class _TextLink extends StatefulWidget {
  const _TextLink(this.text, {this.onTap});
  final String text;
  final VoidCallback? onTap;
  @override
  State<_TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<_TextLink> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Text(widget.text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: hover ? context.c.accent : context.c.fgMuted)),
        ),
      );
}

// ---------------------------------------------------------------- 5.4 employee status

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});
  final Map<String, dynamic> employee;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final segs = _l(employee['segments']);
    final total = '${employee['total'] ?? 0}';
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _title(context, 'Employee Status')),
          const SquareButton(LucideIcons.arrowUpRight, bordered: true, tooltip: 'Open employee status'),
        ]),
        const SizedBox(height: 4),
        Text.rich(TextSpan(style: TextStyle(fontSize: 14, color: c.fgMuted), children: [
          const TextSpan(text: 'Total Employees → '),
          TextSpan(text: total, style: TextStyle(fontWeight: FontWeight.w600, color: c.fg)),
        ])),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Stack(children: [
              SemiDoughnut(values: [for (final s in segs) numOf(s['value'])], colors: [for (final s in segs) cssColor(context, '${s['color']}')]),
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: Column(children: [
                  Text(total, style: display(context, size: 24).copyWith(height: 1)),
                  Text('Employees', style: TextStyle(fontSize: 11, color: c.fgMuted)),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            for (final s in segs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: cssColor(context, '${s['color']}'), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${s['label']} →', style: TextStyle(fontSize: 14, color: c.fgMuted)),
                  const SizedBox(width: 8),
                  Text('${s['value'] ?? 0}'.padLeft(2, '0'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- 5.5 recent orders

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({required this.orders});
  final List<Map<String, dynamic>> orders;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1024 ? 3 : (w >= 640 ? 2 : 1);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
          _title(context, 'Recent Orders'),
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 176,
              child: TextField(
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'eg: search here…',
                  hintStyle: TextStyle(fontSize: 12, color: c.fgMuted),
                  fillColor: c.bg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  prefixIcon: Icon(LucideIcons.search, size: 14, color: c.fgMuted),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.accent)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => context.go('/orders'),
              child: Text('View all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.accent)),
            ),
          ]),
        ]),
        if (orders.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 24), child: Text('No orders yet.', style: TextStyle(fontSize: 14, color: c.fgMuted)))
        else
          Padding(
            padding: const EdgeInsets.only(top: 16),
            // Rows of equal Expanded cells (not LayoutBuilder) so the card works under IntrinsicHeight.
            child: Column(children: [
              for (var r = 0; r < orders.length; r += cols)
                Padding(
                  padding: EdgeInsets.only(top: r == 0 ? 0 : 16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var k = 0; k < cols; k++) ...[
                      if (k > 0) const SizedBox(width: 16),
                      Expanded(child: r + k < orders.length ? _OrderCard(orders[r + k]) : const SizedBox()),
                    ],
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.o);
  final Map<String, dynamic> o;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final img = '${o['image'] ?? ''}';
    final status = '${o['status'] ?? ''}';
    final noImage = Center(child: Text('No image', style: TextStyle(fontSize: 12, color: c.fgMuted)));
    Widget dl(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Text(k, style: TextStyle(fontSize: 12, color: c.fgMuted)),
            const Spacer(),
            Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.fg)),
          ]),
        );
    return Reveal(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 112,
            color: c.bg,
            child: img.isEmpty ? noImage : Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, img, fit: BoxFit.cover, errorBuilder: (_, _, _) => noImage),
          ),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text('${o['customer'] ?? ''}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Text('${o['line'] ?? ''}', style: TextStyle(fontSize: 12, color: c.fgMuted)),
        ]),
        const SizedBox(height: 4),
        dl('Order ID', '${o['orderId'] ?? ''}'),
        dl('Type', '${o['type'] ?? ''}'),
        const SizedBox(height: 12),
        Row(children: [
          StatusBadge(status, label: _orderLabels[status] ?? status),
          const Spacer(),
          Text(money(numOf(o['price'])), style: display(context, size: 16)),
        ]),
      ]),
    ));
  }
}

// ---------------------------------------------------------------- 5.6 sales & order types

class _SalesTypesCard extends StatelessWidget {
  const _SalesTypesCard({required this.types, this.fill = false});
  final List<Map<String, dynamic>> types;

  /// `h-full flex-col` — only when the parent gives a bounded height (lg two-column row).
  final bool fill;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colors = [c.accent, const Color(0xFFF99A55), const Color(0xFFFDD0AA)];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _title(context, 'Sales & Order Types')),
          const SquareButton(LucideIcons.arrowUpRight, bordered: true, tooltip: 'Open sales breakdown'),
        ]),
        const SizedBox(height: 24),
        _maybeExpanded(
          fill,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < types.length; i++)
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(left: i > 0 ? 16 : 0, right: i == 0 ? 16 : 0),
                  child: CustomPaint(
                    painter: i > 0 ? _DashedLeftBorder(c.border) : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${types[i]['label'] ?? ''}', style: TextStyle(fontSize: 12, color: c.fgMuted)),
                      const SizedBox(height: 8),
                      Text('${jsNum(types[i]['percent'])}%', style: display(context, size: 30)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 20),
        SegmentBar(percents: [for (final t in types) numOf(t['percent'])], colors: colors),
      ]),
    );
  }
}

Widget _maybeExpanded(bool fill, Widget child) => fill ? Expanded(child: child) : child;

/// `border-l border-dashed` drawn 16px left of the content (the column's pl-4).
class _DashedLeftBorder extends CustomPainter {
  _DashedLeftBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(-16, y), Offset(-16, (y + 3).clamp(0, size.height)), p);
    }
  }

  @override
  bool shouldRepaint(_DashedLeftBorder old) => old.color != color;
}

// ---------------------------------------------------------------- 5.7 trending menu item

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.res, required this.reload});
  final Map<String, dynamic> res;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = _m(_m(res['data'])['trending']);
    final img = '${t['image'] ?? ''}';
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _title(context, 'Trending Menu Item')),
          if (res['editable'] == true) SquareButton(LucideIcons.pencil, tooltip: 'Edit trending item', onPressed: () => _edit(context)),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(height: 176, child: img.isEmpty ? const SizedBox() : Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, img, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t['name'] ?? ''}', style: display(context, size: 16)),
              Text('${t['subtitle'] ?? ''}', style: TextStyle(fontSize: 12, color: c.fgMuted)),
            ]),
          ),
          const SizedBox(width: 12),
          Text(money(numOf(t['price'])), style: display(context, size: 20, color: c.accent)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.star_rounded, size: 18, color: c.gold),
          const SizedBox(width: 4),
          Text(jsNum(t['rating'] ?? 0), style: TextStyle(fontSize: 14, color: c.fgMuted)),
          const SizedBox(width: 16),
          Icon(LucideIcons.clock, size: 16, color: c.fgMuted),
          const SizedBox(width: 4),
          Text('${t['orders'] ?? 0}', style: TextStyle(fontSize: 14, color: c.fgMuted)),
        ]),
      ]),
    );
  }

  void _edit(BuildContext context) {
    final options = _l(res['menuOptions']);
    final current = res['currentItemId'] as String? ?? 'AUTO';
    showAppModal<void>(context, title: 'Trending menu item', builder: (ctx) => _TrendingEditor(options: options, initial: current, reload: reload));
  }
}

class _TrendingEditor extends StatefulWidget {
  const _TrendingEditor({required this.options, required this.initial, required this.reload});
  final List<Map<String, dynamic>> options;
  final String initial;
  final Future<void> Function() reload;
  @override
  State<_TrendingEditor> createState() => _TrendingEditorState();
}

class _TrendingEditorState extends State<_TrendingEditor> {
  late String choice = widget.initial;
  bool pending = false;

  Future<void> _save() async {
    setState(() => pending = true);
    try {
      await Api.post('/dashboard/trending', {'itemId': choice == 'AUTO' ? null : choice});
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
    await widget.reload();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppSelect<String>(
          label: 'Featured item',
          value: choice,
          items: [('AUTO', 'Auto — most ordered'), for (final m in widget.options) ('${m['id']}', '${m['name']}')],
          onChanged: (v) => setState(() => choice = v),
        ),
        const SizedBox(height: 4),
        Text('Choose a dish to feature, or Auto to use the best-seller.', style: TextStyle(fontSize: 12, color: context.c.fgMuted)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Btn('Cancel', kind: BtnKind.ghost, onPressed: () => Navigator.of(context).pop()),
          const SizedBox(width: 12),
          Btn(pending ? 'Saving…' : 'Save', onPressed: pending ? null : _save),
        ]),
      ]);
}

// ---------------------------------------------------------------- 5.8 POS activities

class _PosCard extends StatelessWidget {
  const _PosCard({required this.pos});
  final Map<String, dynamic> pos;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pay = _m(pos['payment']);
    final cash = jsNum(pay['cash'] ?? 0);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: _title(context, 'POS Activities')), const StaticFilterPill("Today's")]),
        const SizedBox(height: 16),
        Row(children: [
          Text('Total Sales', style: TextStyle(fontSize: 14, color: c.fgMuted)),
          const SizedBox(width: 12),
          Text('→', style: TextStyle(color: c.fgMuted)),
        ]),
        const SizedBox(height: 4),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 4, children: [
          Text('${pos['totalSales'] ?? ''}', style: display(context, size: 30)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.trendingUp, size: 12, color: c.success),
              const SizedBox(width: 4),
              Text(_delta(pos['salesDelta'] ?? 0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.success)),
            ]),
          ),
          Text('Since Yesterday', style: TextStyle(fontSize: 12, color: c.fgMuted)),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
          child: Row(children: [
            for (final (l, v) in [('Total Bills', '${pos['totalBills'] ?? 0}'), ('AVG Value', '${pos['avgValue'] ?? ''}'), ('Peak Hour', '${pos['peakHour'] ?? ''}')])
              Expanded(
                child: Column(children: [
                  Text(l, style: TextStyle(fontSize: 12, color: c.fgMuted)),
                  const SizedBox(height: 4),
                  Text(v, style: display(context, size: 18)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Semantics(label: '$cash% Cash Payment', child: TickGauge(value: numOf(pay['cash']), label: '$cash%')),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          LegendDot(c.accent, 'Card ${jsNum(pay['card'] ?? 0)}%'),
          const SizedBox(width: 20),
          LegendDot(const Color(0xFFCBD0D8), 'Online ${jsNum(pay['online'] ?? 0)}%'),
        ]),
        const SizedBox(height: 20),
        Material(
          color: c.accent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            hoverColor: c.accentDeep,
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('View Details', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
            ),
          ),
        ),
      ]),
    );
  }
}
