import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'staff_providers.dart';

const inventoryCategories = ['Produce', 'Meat & Fish', 'Dairy', 'Beverage', 'Dry Goods', 'Bakery'];

String stockStatus(Json i) {
  final q = asNum(i['quantity']);
  if (q <= 0) return 'OUT';
  return q <= asNum(i['reorderLevel']) ? 'LOW' : 'IN_STOCK';
}

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _lowOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.goldBrand,
        foregroundColor: AppColors.ink,
        onPressed: () => _form(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: AsyncBody<List<Json>>(
        value: ref.watch(inventoryProvider),
        onRefresh: () async => ref.refresh(inventoryProvider.future),
        builder: (items) {
          final low = items.where((i) => stockStatus(i) != 'IN_STOCK').toList();
          final value = items.fold<num>(0, (s, i) => s + asNum(i['quantity']) * asNum(i['costPerUnit']));
          final shown = _lowOnly ? low : items;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
            Row(children: [
              Expanded(child: KpiTile(label: 'Stock value', value: moneyCompact(value), icon: Icons.inventory_2_outlined)),
              const SizedBox(width: 10),
              Expanded(child: KpiTile(label: 'Low / out', value: '${low.length}', icon: Icons.warning_amber_rounded, highlight: low.isNotEmpty)),
            ]),
            const SizedBox(height: 10),
            FilterChip(label: const Text('Low stock only'), selected: _lowOnly, onSelected: (v) => setState(() => _lowOnly = v)),
            const SizedBox(height: 6),
            for (final i in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _form(context, item: i),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${i['category']} · reorder at ${_n(i['reorderLevel'])} ${i['unit']}', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        StatusChip(stockStatus(i), label: humanize(stockStatus(i))),
                      ]),
                    ),
                    IconButton.filledTonal(onPressed: () => _adjust(i, -1), icon: const Icon(Icons.remove_rounded)),
                    SizedBox(
                      width: 64,
                      child: Column(children: [
                        Text(_n(i['quantity']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('${i['unit']}', style: TextStyle(color: context.c.muted, fontSize: 11)),
                      ]),
                    ),
                    IconButton.filledTonal(onPressed: () => _adjust(i, 1), icon: const Icon(Icons.add_rounded)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  String _n(Object? v) {
    final n = asNum(v);
    return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
  }

  Future<void> _adjust(Json i, num delta) => guard(context, () async {
        await ref.read(apiProvider).post('$staffApi/inventory/${i['id']}/adjust', {'delta': delta});
        ref.invalidate(inventoryProvider);
      });

  Future<void> _form(BuildContext context, {Json? item}) async {
    final name = TextEditingController(text: item?['name'] as String? ?? '');
    final unit = TextEditingController(text: item?['unit'] as String? ?? 'kg');
    final qty = TextEditingController(text: item == null ? '0' : _n(item['quantity']));
    final reorder = TextEditingController(text: item == null ? '0' : _n(item['reorderLevel']));
    final cost = TextEditingController(text: item == null ? '0' : '${asNum(item['costPerUnit'])}');
    final supplier = TextEditingController(text: item?['supplier'] as String? ?? '');
    var category = inventoryCategories.contains(item?['category']) ? item!['category'] as String : inventoryCategories.first;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(item == null ? 'New stock item' : 'Edit stock item', style: display(ctx, size: 22)),
              const SizedBox(height: 14),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in inventoryCategories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => set(() => category = v ?? category),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit'))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: reorder, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder level'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost / unit', prefixText: '\$ '))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: supplier, decoration: const InputDecoration(labelText: 'Supplier')),
              const SizedBox(height: 16),
              Row(children: [
                if (item != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: ctx.c.danger),
                    onPressed: () async {
                      if (!await confirm(ctx, title: 'Delete ${item['name']}?', confirmLabel: 'Delete', destructive: true) || !ctx.mounted) return;
                      final ok = await guard(ctx, () async {
                        await ref.read(apiProvider).delete('$staffApi/inventory/${item['id']}');
                        ref.invalidate(inventoryProvider);
                      });
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final body = {
                        'name': name.text.trim(),
                        'category': category,
                        'unit': unit.text.trim(),
                        'quantity': num.tryParse(qty.text) ?? 0,
                        'reorderLevel': num.tryParse(reorder.text) ?? 0,
                        'costPerUnit': num.tryParse(cost.text) ?? 0,
                        'supplier': supplier.text.trim(),
                      };
                      final ok = await guard(ctx, () async {
                        final api = ref.read(apiProvider);
                        item == null ? await api.post('$staffApi/inventory', body) : await api.put('$staffApi/inventory/${item['id']}', body);
                        ref.invalidate(inventoryProvider);
                      }, success: 'Saved');
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
