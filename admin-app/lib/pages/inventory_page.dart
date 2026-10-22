import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/biz_widgets.dart';
import '../widgets/ui.dart';

/// inventory/index.blade.php — inventoryManager().
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.get('/inventory')),
        builder: (context, data, _) => _InventoryView(
          items: _rows(data['items']),
          categories: List<String>.from(data['categories'] ?? const ['Produce', 'Meat & Fish', 'Dairy', 'Beverage', 'Dry Goods', 'Bakery']),
        ),
      );
}

List<Map<String, dynamic>> _rows(dynamic v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x)];

String _stockStatus(Map i) {
  final q = numOf(i['quantity']);
  return q <= 0 ? 'OUT' : q <= numOf(i['reorderLevel']) ? 'LOW' : 'IN_STOCK';
}

const _meta = {
  'IN_STOCK': ('In Stock', Tone.success),
  'LOW': ('Low Stock', Tone.warn),
  'OUT': ('Out of Stock', Tone.danger),
};

class _InventoryView extends StatefulWidget {
  const _InventoryView({required this.items, required this.categories});
  final List<Map<String, dynamic>> items;
  final List<String> categories;
  @override
  State<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<_InventoryView> {
  late List<Map<String, dynamic>> items = widget.items;
  String filter = 'All', query = '';

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    return items.where((it) {
      return (filter == 'All' || it['category'] == filter) &&
          (q.isEmpty || '${it['name'] ?? ''}'.toLowerCase().contains(q) || '${it['supplier'] ?? ''}'.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> adjust(Map<String, dynamic> it, int delta) async {
    final prev = it['quantity'];
    setState(() => it['quantity'] = math.max<num>(0, numOf(it['quantity']) + delta));
    final ok = await guard(() => Api.patch('/inventory/${it['id']}/adjust', {'delta': delta}));
    if (!ok && mounted) setState(() => it['quantity'] = prev);
  }

  Future<void> remove(Map<String, dynamic> it) async {
    if (!await confirmDialog(context, 'Remove this inventory item?')) return;
    final before = items;
    setState(() => items = items.where((x) => x['id'] != it['id']).toList());
    final ok = await guard(() => Api.delete('/inventory/${it['id']}'));
    if (!ok && mounted) setState(() => items = before);
  }

  void openForm([Map<String, dynamic>? editing]) {
    showAppModal(
      context,
      title: editing != null ? 'Edit inventory item' : 'Add inventory item',
      builder: (_) => _InventoryForm(
        editing: editing,
        categories: widget.categories,
        onSaved: (list) => setState(() {
          if (list != null) items = list;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = filtered;
    final stockValue = items.fold<num>(0, (s, i) => s + numOf(i['quantity']) * numOf(i['costPerUnit']));
    return Gap(children: [
      StatsGrid(children: [
        StatTile(icon: LucideIcons.package, label: 'Total Items', value: '${items.length}'),
        StatTile(icon: LucideIcons.triangleAlert, label: 'Low Stock', value: '${items.where((i) => _stockStatus(i) == 'LOW').length}'),
        StatTile(icon: LucideIcons.circleX, label: 'Out of Stock', value: '${items.where((i) => _stockStatus(i) == 'OUT').length}'),
        StatTile(icon: LucideIcons.dollarSign, label: 'Stock Value', value: money(stockValue)),
      ]),
      BizToolbar(
        left: FilterPills<String>(options: ['All', ...widget.categories], value: filter, onChanged: (f) => setState(() => filter = f)),
        right: [
          SearchField(hint: 'Search items…', width: 192, onChanged: (v) => setState(() => query = v)),
          Btn('Add Item', icon: LucideIcons.plus, onPressed: () => openForm()),
        ],
      ),
      BizTable(
        empty: 'No inventory items match your filters.',
        columns: const [
          DataCol('Item', flex: 3),
          DataCol('Category', flex: 2),
          DataCol('Supplier', flex: 2),
          DataCol('Stock', flex: 3),
          DataCol('Status', flex: 2),
          DataCol('Actions', flex: 2, align: TextAlign.right),
        ],
        rows: [
          for (final it in rows)
            BizRow(color: _stockStatus(it) == 'OUT' ? c.dangerSoft.withValues(alpha: .3) : null, [
              CellText('${it['name'] ?? ''}', muted: false, weight: FontWeight.w500),
              CellText('${it['category'] ?? ''}'),
              CellText('${it['supplier'] ?? ''}'.isEmpty ? '—' : '${it['supplier']}'),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  SquareBtn(LucideIcons.minus, size: 24, iconSize: 12, tooltip: 'Decrease', onTap: () => adjust(it, -1)),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 64),
                    child: Text('${jsNum(numOf(it['quantity']))} ${it['unit'] ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                  const SizedBox(width: 8),
                  SquareBtn(LucideIcons.plus, size: 24, iconSize: 12, tooltip: 'Increase', onTap: () => adjust(it, 1)),
                ]),
                const SizedBox(height: 2),
                Text('reorder at ${jsNum(numOf(it['reorderLevel']))}', style: TextStyle(fontSize: 12, color: c.fgMuted)),
              ]),
              ToneBadge(_meta[_stockStatus(it)]!.$1, tone: _meta[_stockStatus(it)]!.$2),
              RowActions([
                RowAction(LucideIcons.pencil, tooltip: 'Edit', onTap: () => openForm(it)),
                RowAction(LucideIcons.trash2, tooltip: 'Delete', danger: true, onTap: () => remove(it)),
              ]),
            ]),
        ],
      ),
    ]);
  }
}

class _InventoryForm extends StatefulWidget {
  const _InventoryForm({required this.editing, required this.categories, required this.onSaved});
  final Map<String, dynamic>? editing;
  final List<String> categories;
  final void Function(List<Map<String, dynamic>>? replaced) onSaved;
  @override
  State<_InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<_InventoryForm> {
  late final e = widget.editing;
  late final name = TextEditingController(text: '${e?['name'] ?? ''}');
  late final unit = TextEditingController(text: '${e?['unit'] ?? 'kg'}');
  late final quantity = TextEditingController(text: jsNum(numOf(e?['quantity'] ?? 0)));
  late final reorderLevel = TextEditingController(text: jsNum(numOf(e?['reorderLevel'] ?? 0)));
  late final costPerUnit = TextEditingController(text: jsNum(numOf(e?['costPerUnit'] ?? 0)));
  late final supplier = TextEditingController(text: '${e?['supplier'] ?? ''}');
  late String category = '${e?['category'] ?? 'Dry Goods'}';
  bool saving = false;
  Map<String, String> errors = {};

  @override
  void dispose() {
    for (final c in [name, unit, quantity, reorderLevel, costPerUnit, supplier]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final errs = <String, String>{};
    if (name.text.trim().length < 2) errs['name'] = 'Name is required';
    if (unit.text.trim().isEmpty) errs['unit'] = 'Unit is required';
    for (final f in [quantity, reorderLevel, costPerUnit]) {
      final n = num.tryParse(f.text.trim());
      if (n == null || n < 0) errs['numbers'] = 'Number must be greater than or equal to 0';
    }
    setState(() => errors = errs);
    if (errs.isNotEmpty) return;
    final values = <String, dynamic>{
      'name': name.text,
      'category': category,
      'unit': unit.text,
      'quantity': num.parse(quantity.text.trim()),
      'reorderLevel': num.parse(reorderLevel.text.trim()),
      'costPerUnit': num.parse(costPerUnit.text.trim()),
      'supplier': supplier.text,
    };
    setState(() => saving = true);
    try {
      if (e != null) {
        await Api.put('/inventory/${e!['id']}', values);
        e!.addAll(values);
        widget.onSaved(null);
      } else {
        final res = await Api.post('/inventory', values);
        widget.onSaved(_rows(res['items']));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      toast(err is ApiError ? err.message : '$err', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Gap(gap: 16, children: [
        BizField(label: 'Name', controller: name, hint: 'Sea Bass (whole)', error: errors['name']),
        Cols([
          BizSelect<String>(
            label: 'Category',
            value: category,
            items: [for (final c in widget.categories) (c, c)],
            onChanged: (v) => setState(() => category = v),
          ),
          BizField(label: 'Unit', controller: unit, hint: 'kg, L, units', error: errors['unit']),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Cols([
            BizField(label: 'Quantity', controller: quantity, number: true),
            BizField(label: 'Reorder at', controller: reorderLevel, number: true),
            BizField(label: 'Cost / unit', controller: costPerUnit, number: true),
          ]),
          if (errors['numbers'] != null) ...[const SizedBox(height: 12), Text(errors['numbers']!, style: TextStyle(fontSize: 12, color: context.c.danger))],
        ]),
        BizField(label: 'Supplier', controller: supplier, hint: 'Boston Seafood Co.'),
        ModalActions(submitLabel: e != null ? 'Save changes' : 'Add item', saving: saving, onSubmit: submit),
      ]);
}
