import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'customer_providers.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});
  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String _category = 'All';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    final table = ref.watch(cartProvider.select((c) => c.table));
    return Scaffold(
      appBar: AppBar(title: const Text('Our Menu')),
      body: AsyncBody<MenuData>(
        value: menu,
        onRefresh: () async {
          ref.invalidate(menuProvider);
          await ref.read(menuProvider.future);
        },
        builder: (m) {
          final cats = ['All', ...m.categories];
          final items = m.items.where((i) {
            final q = _query.toLowerCase();
            return (_category == 'All' || i.category == _category) &&
                (q.isEmpty || i.name.toLowerCase().contains(q) || i.description.toLowerCase().contains(q));
          }).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            if (table != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppCard(
                  color: context.c.accentSoft,
                  borderColor: context.c.accent,
                  child: Row(children: [
                    Icon(Icons.table_restaurant_rounded, color: context.c.accent),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Dine-in · Table ${table.number}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    TextButton(onPressed: () => ref.read(cartProvider.notifier).setTable(null), child: const Text('Leave')),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Search dishes, drinks…', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(cats[i]),
                  selected: _category == cats[i],
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _category = cats[i]),
                ),
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyState(icon: Icons.search_off_rounded, title: 'Nothing found', message: 'Try another search or category.'),
              ),
            for (final item in items)
              Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: MenuItemRow(item: item)),
          ]);
        },
      ),
    );
  }
}

class MenuItemRow extends ConsumerWidget {
  const MenuItemRow({super.key, required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) => c.qtyOf(item.id)));
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => showMenuItemSheet(context, item),
      child: Row(children: [
        NetImage(item.imageUrl, width: 92, height: 92),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (item.tag.isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Eyebrow(item.tag)),
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 3),
            Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.c.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [
              Text(money(item.price), style: TextStyle(color: context.c.accent, fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              QtyStepper(
                qty: qty,
                onAdd: () => ref.read(cartProvider.notifier).add(item),
                onRemove: () => ref.read(cartProvider.notifier).remove(item.id),
                addKey: Key('add-${item.id}'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.qty, required this.onAdd, required this.onRemove, this.addKey});
  final int qty;
  final VoidCallback onAdd, onRemove;
  final Key? addKey;

  @override
  Widget build(BuildContext context) {
    if (qty == 0) {
      return SizedBox(
        height: 34,
        child: FilledButton(
          key: addKey,
          onPressed: onAdd,
          style: FilledButton.styleFrom(minimumSize: const Size(72, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
          child: const Text('Add'),
        ),
      );
    }
    return Container(
      height: 34,
      decoration: BoxDecoration(color: context.c.accentSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(visualDensity: VisualDensity.compact, iconSize: 18, onPressed: onRemove, icon: Icon(Icons.remove_rounded, color: context.c.accent)),
        Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(key: addKey, visualDensity: VisualDensity.compact, iconSize: 18, onPressed: onAdd, icon: Icon(Icons.add_rounded, color: context.c.accent)),
      ]),
    );
  }
}

void showMenuItemSheet(BuildContext context, MenuItem item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final qty = ref.watch(cartProvider.select((c) => c.qtyOf(item.id)));
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          NetImage(item.imageUrl, height: 220, width: double.infinity, radius: 20),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Eyebrow(item.category)),
            Icon(Icons.star_rounded, size: 18, color: ctx.c.gold),
            Text(' ${item.rating.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(item.name, style: display(ctx, size: 26)),
          const SizedBox(height: 8),
          Text(item.description, style: TextStyle(color: ctx.c.muted, height: 1.45)),
          const SizedBox(height: 20),
          Row(children: [
            Text(money(item.price), style: display(ctx, size: 24, color: ctx.c.accent)),
            const Spacer(),
            QtyStepper(
              qty: qty,
              onAdd: () => ref.read(cartProvider.notifier).add(item),
              onRemove: () => ref.read(cartProvider.notifier).remove(item.id),
            ),
          ]),
        ]),
      );
    }),
  );
}
