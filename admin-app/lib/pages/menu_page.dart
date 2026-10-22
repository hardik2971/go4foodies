import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/ops_widgets.dart';
import '../widgets/ui.dart';

/// Menu — port of resources/views/menu/index.blade.php (MenuManager + MenuItemForm).
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => asJson(await Api.get('/menu')),
        builder: (context, data, _) => _MenuView(
          items: asJsonList(data['items']),
          categories: asJsonList(data['categories']),
          menuCategories: List<String>.from((data['menuCategories'] as List?) ?? _fallbackCategories),
        ),
      );
}

const _fallbackCategories = ['Breakfast', 'Starters', 'Main Meals', 'Fish', 'Pasta & Salads', 'Desserts', 'Drinks'];
const _defaultImage = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=70';
const _maxUpload = 5 * 1024 * 1024;

bool _isUrl(String v) {
  final u = Uri.tryParse(v.trim());
  return v.trim().isNotEmpty && u != null && u.scheme.isNotEmpty;
}

class _MenuView extends StatefulWidget {
  const _MenuView({required this.items, required this.categories, required this.menuCategories});
  final List<Json> items, categories;
  final List<String> menuCategories;
  @override
  State<_MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<_MenuView> {
  late List<Json> items = widget.items;
  late List<Json> categories = widget.categories;
  List<String> get menuCats => widget.menuCategories;
  String filter = 'All', query = '';
  final rev = Rev();

  // form
  Json? editing;
  final name = TextEditingController(), description = TextEditingController(), tag = TextEditingController();
  final price = TextEditingController(), rating = TextEditingController(), imageUrl = TextEditingController();
  String category = 'Main Meals';
  bool available = true, uploading = false;
  String uploadError = '';
  Map<String, String> errors = {};

  @override
  void dispose() {
    for (final c in [name, description, tag, price, rating, imageUrl]) {
      c.dispose();
    }
    rev.dispose();
    super.dispose();
  }

  void update(VoidCallback fn) {
    if (mounted) setState(fn);
    rev.bump();
  }

  List<Json> get filtered {
    final q = query.trim().toLowerCase();
    return items
        .where((it) => (filter == 'All' || it['category'] == filter) && (q.isEmpty || str(it['name']).toLowerCase().contains(q) || str(it['tag']).toLowerCase().contains(q)))
        .toList();
  }

  void toggleCategory(String id) {
    final cat = categories.where((c) => c['id'] == id).firstOrNull;
    if (cat == null) return;
    final next = cat['active'] != true;
    update(() => categories = [for (final c in categories) c['id'] == id ? {...c, 'active': next} : c]);
    guard(() => Api.patch('/menu/categories/$id/active', {'active': next}));
  }

  void toggleAvailable(String id) {
    final item = items.where((it) => it['id'] == id).firstOrNull;
    if (item == null) return;
    final next = item['available'] != true;
    update(() => items = [for (final it in items) it['id'] == id ? {...it, 'available': next} : it]);
    guard(() => Api.patch('/menu/items/$id/availability', {'available': next}));
  }

  Future<void> remove(String id) async {
    if (!await confirmDialog(context, 'Remove this item from the menu?')) return;
    update(() => items = items.where((it) => it['id'] != id).toList());
    guard(() => Api.delete('/menu/items/$id'));
  }

  void _fill(Json? item) {
    editing = item;
    name.text = str(item?['name']);
    description.text = str(item?['description']);
    price.text = item == null ? '0' : jsNum(item['price']);
    rating.text = item == null ? '0' : jsNum(item['rating']);
    tag.text = str(item?['tag']);
    category = item == null ? 'Main Meals' : str(item['category']);
    imageUrl.text = item == null ? _defaultImage : str(item['imageUrl']);
    available = item == null ? true : item['available'] == true;
    errors = {};
    uploadError = '';
  }

  Future<void> openForm(Json? item) async {
    setState(() => _fill(item));
    await showAppModal(context, title: item != null ? 'Edit menu item' : 'Add menu item', builder: (ctx) => synced(rev, () => _form(ctx)));
  }

  Future<void> handleFile() async {
    final f = await pickImageFile();
    if (f == null) return;
    update(() {
      uploading = true;
      uploadError = '';
    });
    try {
      if (!f.type.startsWith('image/')) throw ApiError(415, 'Only image files are allowed');
      if (f.size > _maxUpload) throw ApiError(413, 'Image must be under 5MB');
      final url = await Api.upload(f.bytes, f.name, f.type);
      imageUrl.text = url;
      errors.remove('imageUrl');
    } on ApiError catch (e) {
      uploadError = e.message;
    } catch (_) {
      uploadError = 'Upload failed';
    } finally {
      update(() => uploading = false);
    }
  }

  bool validate() {
    final e = <String, String>{};
    if (name.text.length < 2) e['name'] = 'Name is required';
    if (description.text.length < 4) e['description'] = 'Add a short description';
    final p = num.tryParse(price.text.trim());
    if (price.text.isEmpty || p == null || p.isNaN || p < 0) e['price'] = 'Price must be positive';
    final r = rating.text.trim().isEmpty ? 0 : num.tryParse(rating.text.trim());
    if (r == null || r.isNaN || r < 0) {
      e['rating'] = 'Number must be greater than or equal to 0';
    } else if (r > 5) {
      e['rating'] = 'Number must be less than or equal to 5';
    }
    if (!_isUrl(imageUrl.text)) e['imageUrl'] = 'Enter a valid image URL';
    update(() => errors = e);
    return e.isEmpty;
  }

  Future<void> submit(BuildContext ctx) async {
    if (!validate()) return;
    final values = <String, dynamic>{
      'name': name.text,
      'description': description.text,
      'price': num.parse(price.text.trim()),
      'rating': rating.text.trim().isEmpty ? 0 : num.parse(rating.text.trim()),
      'tag': tag.text,
      'category': category,
      'imageUrl': imageUrl.text,
      'available': available,
    };
    Navigator.of(ctx).pop();
    if (editing != null) {
      final id = editing!['id'];
      update(() => items = [for (final it in items) it['id'] == id ? {...it, ...values} : it]);
      guard(() => Api.put('/menu/items/$id', values));
    } else {
      update(() => items = [{'id': 'tmp-${DateTime.now().millisecondsSinceEpoch}', ...values}, ...items]);
      await guard(() async {
        final res = asJson(await Api.post('/menu/items', values));
        update(() {
          if (res['items'] != null) items = asJsonList(res['items']);
          if (res['categories'] != null) categories = asJsonList(res['categories']);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = filtered;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (categories.isNotEmpty) ...[
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 4, children: [
              Text('CATEGORIES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .6, color: c.fgMuted)),
              Muted('Disabled categories are hidden from the website menu', size: 12),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final cat in categories) _categoryChip(cat)]),
          ]),
        ),
        const SizedBox(height: 20),
      ],
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        FilterPills<String>(options: ['All', ...menuCats], value: filter, onChanged: (v) => setState(() => filter = v)),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(hint: 'Search dishes…', width: 192, onChanged: (v) => setState(() => query = v)),
          Btn('Add Item', icon: LucideIcons.plus, onPressed: () => openForm(null)),
        ]),
      ]),
      const SizedBox(height: 20),
      DataTableCard(
        columns: const [
          DataCol('Item', flex: 3),
          DataCol('Category', flex: 2),
          DataCol('Price'),
          DataCol('Rating'),
          DataCol('Status'),
          DataCol('Actions', align: TextAlign.right),
        ],
        minWidth: 800,
        empty: 'No dishes match your filters.',
        rows: [
          for (final it in rows)
            [
              Row(children: [
                NetImage(str(it['imageUrl']), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(str(it['name']), style: const TextStyle(fontWeight: FontWeight.w500)),
                    Muted(str(it['tag']), size: 12),
                  ]),
                ),
              ]),
              Muted(str(it['category']), size: 14),
              Text(money(it['price']), style: const TextStyle(fontWeight: FontWeight.w500)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 16, color: c.gold),
                const SizedBox(width: 4),
                Text(jsNum(it['rating'])),
              ]),
              Tooltip(
                message: it['available'] == true ? 'Available' : 'Unavailable',
                child: MiniSwitch(value: it['available'] == true, onTap: () => toggleAvailable(str(it['id']))),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconBtn(LucideIcons.pencil, onPressed: () => openForm(it)),
                const SizedBox(width: 6),
                IconBtn(LucideIcons.trash2, onPressed: () => remove(str(it['id']))),
              ]),
            ],
        ],
        footer: 'Showing ${rows.length} of ${items.length} items. Changes are in-session until the MySQL data layer is connected.',
      ),
    ]);
  }

  Widget _categoryChip(Json cat) {
    final c = context.c;
    final on = cat['active'] == true;
    final fg = on ? c.success : c.fgMuted;
    return Tooltip(
      message: on ? 'Click to hide from website' : 'Click to show on website',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => toggleCategory(str(cat['id'])),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? c.successSoft : c.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? c.success.withValues(alpha: .4) : c.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(on ? LucideIcons.eye : LucideIcons.eyeOff, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(str(cat['name']),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg, decoration: on ? null : TextDecoration.lineThrough, decorationColor: fg)),
            const SizedBox(width: 6),
            Opacity(opacity: .7, child: Text('(${cat['itemCount'] ?? 0})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg))),
          ]),
        ),
      ),
    );
  }

  Widget _err(String? e) => e == null ? const SizedBox() : Padding(padding: const EdgeInsets.only(top: 4), child: Text(e, style: TextStyle(fontSize: 12, color: context.c.danger)));

  Widget _form(BuildContext ctx) {
    final c = ctx.c;
    const gap = SizedBox(height: 16);
    final url = imageUrl.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LabeledField(label: 'Name', controller: name, hint: 'Truffle Risotto', error: errors['name']),
      gap,
      LabeledField(label: 'Description', controller: description, hint: 'Short description of the dish…', maxLines: 2, error: errors['description']),
      gap,
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: AppSelect<String>(
            label: 'Category',
            value: category,
            items: [for (final m in menuCats) (m, m)],
            onChanged: (v) => update(() => category = v),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: LabeledField(label: 'Tag', controller: tag, hint: 'Popular')),
      ]),
      gap,
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const FieldLabel(r'Price ($)'),
            AppInput(controller: price, hint: '26', number: true),
            _err(errors['price']),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const FieldLabel('Rating (0–5)'),
            AppInput(controller: rating, hint: '4.8', number: true),
            _err(errors['rating']),
          ]),
        ),
      ]),
      gap,
      const FieldLabel('Image'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: c.bg, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: url.isNotEmpty ? NetImage(url, size: 64, radius: 0) : Text('No image', style: TextStyle(fontSize: 10, color: c.fgMuted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: AppInput(controller: imageUrl, hint: 'https://… or upload →', onChanged: (_) => rev.bump())),
              const SizedBox(width: 8),
              Btn(uploading ? 'Uploading…' : 'Upload', kind: BtnKind.ghost, icon: LucideIcons.upload, busy: uploading, onPressed: uploading ? null : handleFile),
            ]),
            const SizedBox(height: 4),
            Muted('Paste an image URL or upload a file (max 5MB).', size: 12),
            if (uploadError.isNotEmpty) _err(uploadError),
            _err(errors['imageUrl']),
          ]),
        ),
      ]),
      gap,
      InkWell(
        onTap: () => update(() => available = !available),
        child: Row(children: [
          SizedBox(width: 20, height: 20, child: Checkbox(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact, value: available, onChanged: (v) => update(() => available = v ?? false))),
          const SizedBox(width: 8),
          const Text('Available on menu', style: TextStyle(fontSize: 14)),
        ]),
      ),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn('Cancel', kind: BtnKind.ghost, onPressed: () => Navigator.of(ctx).pop()),
        const SizedBox(width: 12),
        Btn(editing != null ? 'Save changes' : 'Add item', onPressed: () => submit(ctx)),
      ]),
    ]);
  }
}
