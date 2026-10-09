import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'staff_providers.dart';

const menuCategories = ['Breakfast', 'Starters', 'Main Meals', 'Fish', 'Pasta & Salads', 'Desserts', 'Drinks'];

/// Menu management (admin /menu): availability, category on/off, and full
/// item CRUD for roles with manage:menu.
class MenuAdminScreen extends ConsumerStatefulWidget {
  const MenuAdminScreen({super.key});
  @override
  ConsumerState<MenuAdminScreen> createState() => _MenuAdminScreenState();
}

class _MenuAdminScreenState extends ConsumerState<MenuAdminScreen> {
  String _q = '';
  String _cat = 'All';

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(sessionProvider).profile?.can('manage:menu') == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          if (canEdit)
            IconButton(tooltip: 'Categories', icon: const Icon(Icons.category_outlined), onPressed: () => _categories(context)),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              backgroundColor: AppColors.goldBrand,
              foregroundColor: AppColors.ink,
              onPressed: () => openMenuItemForm(context, ref),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: AsyncBody<Json>(
        value: ref.watch(staffMenuProvider),
        onRefresh: () async => ref.refresh(staffMenuProvider.future),
        builder: (data) {
          final items = ((data['items'] as List?) ?? const []).cast<Json>();
          final cats = ['All', ...{for (final i in items) i['category'] as String}];
          final shown = items
              .where((i) => (_cat == 'All' || i['category'] == _cat) && (i['name'] as String).toLowerCase().contains(_q.toLowerCase()))
              .toList();
          final off = items.where((i) => i['available'] != true).length;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
            TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Search menu', prefixIcon: Icon(Icons.search_rounded))),
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(top: 8), children: [
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(c), selected: _cat == c, showCheckmark: false, onSelected: (_) => setState(() => _cat = c)),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('${items.length} items · $off unavailable', style: TextStyle(color: context.c.muted)),
            ),
            for (final i in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(10),
                  onTap: canEdit ? () => openMenuItemForm(context, ref, item: i) : null,
                  child: Row(children: [
                    Opacity(opacity: i['available'] == true ? 1 : 0.4, child: NetImage(i['imageUrl'] as String? ?? '', width: 60, height: 60, radius: 12)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${i['category']} · ${money(asNum(i['price']))}', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                      ]),
                    ),
                    if (canEdit)
                      Switch(
                        value: i['available'] == true,
                        onChanged: (v) => guard(context, () async {
                          await ref.read(apiProvider).patch('$staffApi/menu/${i['id']}/availability', {'available': v});
                          ref.invalidate(staffMenuProvider);
                        }, success: v ? '${i['name']} available' : '${i['name']} marked unavailable'),
                      )
                    else
                      StatusChip(i['available'] == true ? 'AVAILABLE' : 'OUT', label: i['available'] == true ? 'Available' : 'Sold out'),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  void _categories(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final cats = ((ref.watch(staffMenuProvider).valueOrNull?['categories'] as List?) ?? const []).cast<Json>();
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Categories', style: display(ctx, size: 20)),
            Text('Disabled categories are hidden from the website and customer app.', style: TextStyle(color: ctx.c.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            for (final cat in cats)
              SwitchListTile(
                title: Text(cat['name'] as String),
                subtitle: Text('${cat['itemCount']} items'),
                value: cat['active'] == true,
                onChanged: (v) => guard(ctx, () async {
                  await ref.read(apiProvider).patch('$staffApi/categories/${cat['id']}', {'active': v});
                  ref.invalidate(staffMenuProvider);
                }),
              ),
          ]),
        );
      }),
    );
  }
}

Future<void> openMenuItemForm(BuildContext context, WidgetRef ref, {Json? item}) async {
  final name = TextEditingController(text: item?['name'] as String? ?? '');
  final desc = TextEditingController(text: item?['description'] as String? ?? '');
  final price = TextEditingController(text: item == null ? '' : '${asNum(item['price'])}');
  final rating = TextEditingController(text: item == null ? '4.5' : '${asNum(item['rating'])}');
  final tag = TextEditingController(text: item?['tag'] as String? ?? '');
  final image = TextEditingController(text: item?['imageUrl'] as String? ?? '');
  var category = menuCategories.contains(item?['category']) ? item!['category'] as String : menuCategories.first;
  var available = item?['available'] as bool? ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(item == null ? 'New menu item' : 'Edit item', style: display(ctx, size: 22)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price', prefixText: '\$ '))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: rating, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rating (0–5)'))),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in menuCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => set(() => category = v ?? category),
            ),
            const SizedBox(height: 10),
            TextField(controller: tag, decoration: const InputDecoration(labelText: 'Tag (e.g. Chef’s pick)')),
            const SizedBox(height: 10),
            TextField(controller: image, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Image URL')),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Available'), value: available, onChanged: (v) => set(() => available = v)),
            const SizedBox(height: 8),
            Row(children: [
              if (item != null)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: ctx.c.danger),
                  onPressed: () async {
                    if (!await confirm(ctx, title: 'Delete ${item['name']}?', confirmLabel: 'Delete', destructive: true)) return;
                    if (!ctx.mounted) return;
                    final ok = await guard(ctx, () async {
                      await ref.read(apiProvider).delete('$staffApi/menu/${item['id']}');
                      ref.invalidate(staffMenuProvider);
                    }, success: 'Item deleted');
                    if (ok && ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final body = {
                      'name': name.text.trim(),
                      'description': desc.text.trim(),
                      'price': num.tryParse(price.text) ?? 0,
                      'rating': num.tryParse(rating.text) ?? 0,
                      'tag': tag.text.trim(),
                      'category': category,
                      'imageUrl': image.text.trim(),
                      'available': available,
                    };
                    final ok = await guard(ctx, () async {
                      final api = ref.read(apiProvider);
                      item == null ? await api.post('$staffApi/menu', body) : await api.put('$staffApi/menu/${item['id']}', body);
                      ref.invalidate(staffMenuProvider);
                    }, success: item == null ? 'Item added' : 'Item updated');
                    if (ok && ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(item == null ? 'Add item' : 'Save changes'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
