import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/ops_widgets.dart';
import '../widgets/ui.dart';

/// Tables / QR management — port of resources/views/tables/index.blade.php (TablesManager).
class TablesPage extends StatelessWidget {
  const TablesPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => asJson(await Api.get('/tables')),
        builder: (context, data, _) => _TablesView(tables: asJsonList(data['tables']), websiteUrl: str(data['websiteUrl'])),
      );
}

const _labels = {'ACTIVE': 'Active', 'INACTIVE': 'Inactive'};

class _TablesView extends StatefulWidget {
  const _TablesView({required this.tables, required this.websiteUrl});
  final List<Json> tables;
  final String websiteUrl;
  @override
  State<_TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends State<_TablesView> {
  late List<Json> tables = widget.tables;
  String query = '', statusFilter = 'ALL';
  final rev = Rev();

  // form
  Json? editing;
  final number = TextEditingController(), name = TextEditingController();
  String formStatus = 'ACTIVE', error = '';

  @override
  void dispose() {
    number.dispose();
    name.dispose();
    rev.dispose();
    super.dispose();
  }

  void update(VoidCallback fn) {
    if (mounted) setState(fn);
    rev.bump();
  }

  List<Json> get filtered {
    final q = query.trim().toLowerCase();
    return tables
        .where((t) => (statusFilter == 'ALL' || t['status'] == statusFilter) && (q.isEmpty || str(t['number']).toLowerCase().contains(q) || str(t['name']).toLowerCase().contains(q)))
        .toList();
  }

  String tableUrl(dynamic code) => '${widget.websiteUrl}/order?table=${Uri.encodeComponent(str(code))}';

  Future<void> downloadQR(Json t) async {
    try {
      final png = await qrPng(tableUrl(t['code']), 600);
      downloadBytes('table-${t['number']}-qr.png', png, 'image/png');
    } catch (_) {/* ignore */}
  }

  Future<void> printQR(Json t) => printHtmlAsync(_qrPrintDoc(t), width: 420, height: 620);

  Future<String> _qrPrintDoc(Json t) async {
    final src = await qrDataUrl(tableUrl(t['code']), 300);
    final nm = has(t['name']) ? ' &middot; ${esc(t['name'])}' : '';
    return '''<!doctype html><html><head><title>Table ${esc(t['number'])} · QR</title>
<style>body{font-family:system-ui,sans-serif;text-align:center;padding:32px;color:#0a1c18}
h1{font-size:18px;letter-spacing:.18em;text-transform:uppercase;margin:0 0 4px}
p{color:#6b6b6b;margin:4px 0 20px}img{width:300px;height:300px}</style></head>
<body><h1>Go4Foodie</h1>
<p>Scan to order &middot; Table ${esc(t['number'])}$nm</p>
<img src="$src" onload="window.focus();window.print();" alt="QR" />
</body></html>''';
  }

  void toggleStatus(Json t) {
    final next = t['status'] == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    update(() => tables = [for (final x in tables) x['id'] == t['id'] ? {...x, 'status': next} : x]);
    guard(() => Api.patch('/tables/${t['id']}/status', {'status': next}));
  }

  Future<void> remove(Json t) async {
    if (!await confirmDialog(context, 'Delete table ${t['number']}? Its QR code will stop working.')) return;
    update(() => tables = tables.where((x) => x['id'] != t['id']).toList());
    guard(() => Api.delete('/tables/${t['id']}'));
  }

  Future<void> openForm(Json? t) async {
    setState(() {
      editing = t;
      number.text = str(t?['number']);
      name.text = str(t?['name']);
      formStatus = t == null ? 'ACTIVE' : str(t['status']);
      error = '';
    });
    await showAppModal(context, title: t != null ? 'Edit table' : 'Add table', builder: (ctx) => synced(rev, () => _form(ctx)));
  }

  Future<void> submit(BuildContext ctx) async {
    if (number.text.trim().isEmpty) {
      update(() => error = 'Table number is required');
      return;
    }
    final values = {'number': number.text, 'name': name.text, 'status': formStatus};
    if (editing != null) {
      final id = editing!['id'];
      update(() => tables = [
            for (final t in tables)
              t['id'] == id
                  ? ({...t, 'number': values['number'], 'name': values['name']!.isEmpty ? null : values['name'], 'status': values['status']}..removeWhere((k, v) => k == 'name' && v == null))
                  : t
          ]);
      Navigator.of(ctx).pop();
      guard(() => Api.put('/tables/$id', values));
    } else {
      await guard(() async {
        final res = asJson(await Api.post('/tables', values));
        if (res['table'] != null) update(() => tables = [asJson(res['table']), ...tables]);
      });
      if (ctx.mounted) Navigator.of(ctx).pop();
    }
  }

  Future<void> showQr(Json t) => showAppModal(context, title: 'Table ${t['number']} · QR code', builder: (ctx) {
        final c = ctx.c;
        final url = tableUrl(t['code']);
        return Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
            child: Semantics(label: 'Table ${t['number']} QR', child: QrBox(url, size: 224)),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => openNewTab(url),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.externalLink, size: 14, color: c.accent),
              const SizedBox(width: 6),
              Flexible(child: Text(url, style: TextStyle(fontSize: 12, color: c.accent))),
            ]),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Btn('Download', kind: BtnKind.ghost, icon: LucideIcons.download, onPressed: () => downloadQR(t)),
            const SizedBox(width: 12),
            Btn('Print', icon: LucideIcons.printer, onPressed: () => printQR(t)),
          ]),
        ]);
      });

  @override
  Widget build(BuildContext context) {
    final rows = filtered;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        FilterPills<String>(
          options: const ['ALL', 'ACTIVE', 'INACTIVE'],
          value: statusFilter,
          label: (s) => s == 'ALL' ? 'All' : _labels[s]!,
          onChanged: (v) => setState(() => statusFilter = v),
        ),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(hint: 'Search tables…', width: 192, onChanged: (v) => setState(() => query = v)),
          Btn('Add Table', icon: LucideIcons.plus, onPressed: () => openForm(null)),
        ]),
      ]),
      const SizedBox(height: 20),
      if (rows.isEmpty)
        AppCard(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 64), child: Center(child: Muted('No tables match your filters.', size: 14)))
      else
        ColsGrid(cols: (w) => colsFor(w), children: [for (final t in rows) _card(t)]),
    ]);
  }

  Widget _card(Json t) {
    final c = context.c;
    final active = t['status'] == 'ACTIVE';
    Widget act(IconData icon, String tip, VoidCallback onTap, {bool danger = false}) => _HoverIcon(icon: icon, tooltip: tip, onTap: onTap, danger: danger);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Table ${t['number']}', style: display(context, size: 18)),
              if (has(t['name'])) Muted(str(t['name']), size: 12),
            ]),
          ),
          Tooltip(
            message: active ? 'Click to deactivate' : 'Click to activate',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => toggleStatus(t),
              child: toneBadge(context, str(t['status']), _labels[t['status']] ?? str(t['status'])),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Tooltip(
          message: 'View QR code',
          child: InkWell(
            onTap: () => showQr(t),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Semantics(label: 'Table ${t['number']} QR', child: QrBox(tableUrl(t['code']), size: 112)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('${t['orderCount'] ?? 0} orders', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.fgMuted)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
          child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
            act(LucideIcons.qrCode, 'QR', () => showQr(t)),
            act(LucideIcons.download, 'Download', () => downloadQR(t)),
            act(LucideIcons.printer, 'Print', () => printQR(t)),
            Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 4), color: c.border),
            act(LucideIcons.pencil, 'Edit', () => openForm(t)),
            act(LucideIcons.trash2, 'Delete', () => remove(t), danger: true),
          ]),
        ),
      ]),
    );
  }

  Widget _form(BuildContext ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: LabeledField(label: 'Table number', controller: number, hint: '12', error: error.isEmpty ? null : error)),
        const SizedBox(width: 16),
        Expanded(child: LabeledField(label: 'Table name', controller: name, hint: 'Window / Patio')),
      ]),
      const SizedBox(height: 16),
      AppSelect<String>(
        label: 'Status',
        value: formStatus,
        items: const [('ACTIVE', 'Active'), ('INACTIVE', 'Inactive')],
        onChanged: (v) => update(() => formStatus = v),
      ),
      const SizedBox(height: 4),
      Muted('Inactive tables stop accepting QR orders.', size: 12),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn('Cancel', kind: BtnKind.ghost, onPressed: () => Navigator.of(ctx).pop()),
        const SizedBox(width: 12),
        Btn(editing != null ? 'Save changes' : 'Add table', onPressed: () => submit(ctx)),
      ]),
    ]);
  }
}

/// Icon button with accent (or danger) hover tint, like the card action row.
class _HoverIcon extends StatefulWidget {
  const _HoverIcon({required this.icon, required this.tooltip, required this.onTap, this.danger = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  @override
  State<_HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<_HoverIcon> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = widget.danger ? c.danger : c.accent;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: hover ? (widget.danger ? c.dangerSoft : c.accentSoft) : null, borderRadius: BorderRadius.circular(8)),
            child: Icon(widget.icon, size: 16, color: hover ? tint : c.fgMuted),
          ),
        ),
      ),
    );
  }
}
