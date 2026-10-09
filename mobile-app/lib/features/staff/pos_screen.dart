import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'floor_screen.dart';
import 'staff_providers.dart';
import 'table_history_screen.dart';

/// Table POS — mirrors the admin's /pos/[tableId]: seat guests, send KOTs,
/// void items, discount/tax/service/tip, split payments, merge, close & pay.
class PosScreen extends ConsumerWidget {
  const PosScreen({super.key, required this.tableId});
  final String tableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(posProvider(tableId));
    final profile = ref.watch(sessionProvider).profile;
    final table = pos.valueOrNull?['table'] as Json?;
    return Scaffold(
      appBar: AppBar(
        title: Text(table == null ? 'Table' : 'Table ${table['number']}'),
        actions: [
          if (table != null && profile?.can('view:reports') == true)
            IconButton(
              tooltip: 'History',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TableHistoryScreen(tableId: tableId))),
            ),
          if (table != null && profile?.can('operate:floor') == true)
            IconButton(
              tooltip: 'Table state',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () async {
                await showTableStateSheet(context, ref, table);
                ref.read(posProvider(tableId).notifier).refresh();
              },
            ),
        ],
      ),
      body: AsyncBody<Json>(
        value: pos,
        onRefresh: () => ref.read(posProvider(tableId).notifier).refresh(),
        builder: (data) {
          final session = data['session'] as Json?;
          return session == null ? _SeatGuests(tableId: tableId, data: data) : _OpenSession(tableId: tableId, data: data, session: session);
        },
      ),
    );
  }
}

class _SeatGuests extends ConsumerStatefulWidget {
  const _SeatGuests({required this.tableId, required this.data});
  final String tableId;
  final Json data;
  @override
  ConsumerState<_SeatGuests> createState() => _SeatGuestsState();
}

class _SeatGuestsState extends ConsumerState<_SeatGuests> {
  int _guests = 2;
  String? _waiter;
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.data['table'] as Json;
    final waiters = ((widget.data['waiters'] as List?) ?? const []).cast<Json>();
    final canOpen = ref.watch(sessionProvider).profile?.can('operate:floor') == true;
    final c = context.c;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
      AppCard(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: stateColor(context, table['state'] as String).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.table_restaurant_rounded, color: stateColor(context, table['state'] as String)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Table ${table['number']}${table['name'] != null ? ' · ${table['name']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('Seats ${table['capacity']}', style: TextStyle(color: c.muted)),
            ]),
          ),
          StatusChip(table['state'] as String),
        ]),
      ),
      const SectionTitle('Seat guests', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Guests', style: TextStyle(fontWeight: FontWeight.w700))),
            IconButton.filledTonal(onPressed: _guests > 1 ? () => setState(() => _guests--) : null, icon: const Icon(Icons.remove_rounded)),
            SizedBox(width: 44, child: Text('$_guests', textAlign: TextAlign.center, style: display(context, size: 22))),
            IconButton.filledTonal(onPressed: () => setState(() => _guests++), icon: const Icon(Icons.add_rounded)),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _waiter,
            decoration: const InputDecoration(labelText: 'Waiter (optional)'),
            items: [for (final w in waiters) DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] as String))],
            onChanged: (v) => setState(() => _waiter = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Guest name (optional)')),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('open-table'),
            onPressed: !canOpen || _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await guard(context, () => ref.read(posProvider(widget.tableId).notifier).open(guests: _guests, waiterId: _waiter, customerName: _name.text.trim()),
                        success: 'Table opened');
                    ref.invalidate(floorProvider);
                    if (mounted) setState(() => _busy = false);
                  },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Open table'),
          ),
          if (!canOpen) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Your role cannot open tables.', style: TextStyle(color: c.muted))),
        ]),
      ),
    ]);
  }
}

class _OpenSession extends ConsumerWidget {
  const _OpenSession({required this.tableId, required this.data, required this.session});
  final String tableId;
  final Json data;
  final Json session;

  PosController _pos(WidgetRef ref) => ref.read(posProvider(tableId).notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final lines = ((session['lines'] as List?) ?? const []).cast<Json>();
    final payments = ((session['payments'] as List?) ?? const []).cast<Json>();
    final orders = ((session['orders'] as List?) ?? const []).cast<Json>();
    final remaining = asNum(session['remaining']);
    final canClose = ref.watch(sessionProvider).profile?.can('operate:floor') == true;

    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
        AppCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(session['customerName'] as String? ?? 'Guests', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  '${session['customerCount']} guests · opened ${fmtTime(session['openedAt'])}${session['waiterName'] != null ? ' · ${session['waiterName']}' : ''}',
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(asNum(session['total'])), style: display(context, size: 22)),
              Text('${orders.length} KOT${orders.length == 1 ? '' : 's'}', style: TextStyle(color: c.muted, fontSize: 12)),
            ]),
          ]),
        ),
        SectionTitle('Items', action: 'Add items', onAction: () => _addItems(context, ref), padding: const EdgeInsets.fromLTRB(4, 18, 0, 6)),
        if (lines.isEmpty)
          AppCard(child: Text('No items yet — tap “Add items” to send a KOT to the kitchen.', style: TextStyle(color: c.muted)))
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(children: [
              for (final l in lines)
                ListTile(
                  dense: true,
                  title: Text(l['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('${l['qty']} × ${money(asNum(l['price']))}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(money(asNum(l['qty']) * asNum(l['price'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(
                      tooltip: 'Void one',
                      icon: Icon(Icons.remove_circle_outline_rounded, color: c.danger),
                      onPressed: () => guard(context, () => _pos(ref).voidItem(l['menuItemId'] as String)),
                    ),
                  ]),
                ),
            ]),
          ),
        SectionTitle('Bill', action: 'Adjust', onAction: () => _adjust(context, ref), padding: const EdgeInsets.fromLTRB(4, 18, 0, 6)),
        AppCard(
          child: Column(children: [
            KeyValue('Subtotal', money(asNum(session['subtotal']))),
            if (asNum(session['discount']) > 0) KeyValue('Discount', '− ${money(asNum(session['discount']))}', valueColor: c.success),
            if (asNum(session['tax']) > 0) KeyValue('Tax', money(asNum(session['tax']))),
            if (asNum(session['serviceCharge']) > 0) KeyValue('Service charge', money(asNum(session['serviceCharge']))),
            if (asNum(session['tip']) > 0) KeyValue('Tip', money(asNum(session['tip']))),
            const Divider(height: 20),
            KeyValue('Total', money(asNum(session['total'])), bold: true),
            KeyValue('Paid', money(asNum(session['paid']))),
            KeyValue('Remaining', money(remaining), bold: true, valueColor: remaining > 0 ? c.accent : c.success),
          ]),
        ),
        if (payments.isNotEmpty) ...[
          const SectionTitle('Payments', padding: EdgeInsets.fromLTRB(4, 18, 4, 6)),
          AppCard(
            child: Column(children: [
              for (final p in payments) KeyValue('${p['method']} · ${fmtTime(p['createdAt'])}', money(asNum(p['amount']))),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(onPressed: () => _addPayment(context, ref, remaining), icon: const Icon(Icons.payments_outlined), label: const Text('Payment')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(onPressed: () => _merge(context, ref), icon: const Icon(Icons.merge_rounded), label: const Text('Merge')),
          ),
        ]),
      ]),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          color: c.surface,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pos-add-items'),
                onPressed: () => _addItems(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add items'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('pos-close'),
                onPressed: canClose ? () => _close(context, ref, remaining) : null,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Close & pay'),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Future<void> _addItems(BuildContext context, WidgetRef ref) async {
    final menu = ((data['menu'] as List?) ?? const []).cast<Json>();
    final picked = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MenuPicker(menu: menu),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    await guard(
      context,
      () => _pos(ref).addItems([for (final e in picked.entries) {'menuItemId': e.key, 'qty': e.value}]),
      success: 'KOT sent to kitchen',
    );
    ref.invalidate(floorProvider);
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref) async {
    final fields = {
      'discount': TextEditingController(text: '${asNum(session['discount'])}'),
      'tax': TextEditingController(text: '${asNum(session['tax'])}'),
      'serviceCharge': TextEditingController(text: '${asNum(session['serviceCharge'])}'),
      'tip': TextEditingController(text: '${asNum(session['tip'])}'),
    };
    final subtotal = asNum(session['subtotal']);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Adjust bill', style: display(ctx, size: 22)),
          Text('Subtotal ${money(subtotal)}', style: TextStyle(color: ctx.c.muted)),
          const SizedBox(height: 14),
          for (final e in fields.entries) ...[
            TextField(
              controller: e.value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: humanize(e.key == 'serviceCharge' ? 'SERVICE_CHARGE' : e.key.toUpperCase()),
                prefixText: '\$ ',
                suffixIcon: e.key == 'tip'
                    ? null
                    : PopupMenuButton<int>(
                        tooltip: '% of subtotal',
                        icon: const Icon(Icons.percent_rounded),
                        itemBuilder: (_) => [for (final p in [5, 10, 12, 15, 18]) PopupMenuItem(value: p, child: Text('$p%'))],
                        onSelected: (p) => e.value.text = (subtotal * p / 100).toStringAsFixed(2),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final ok = await guard(ctx, () => _pos(ref).billing({for (final e in fields.entries) e.key: num.tryParse(e.value.text) ?? 0}));
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ]),
      ),
    );
  }

  Future<void> _addPayment(BuildContext context, WidgetRef ref, num remaining) async {
    final amount = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(2) : '');
    var method = paymentMethods.first;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add payment', style: display(ctx, size: 22)),
            Text('Split bills or take part payments — remaining ${money(remaining)}', style: TextStyle(color: ctx.c.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in paymentMethods) ChoiceChip(label: Text(m), selected: method == m, showCheckmark: false, onSelected: (_) => set(() => method = m)),
            ]),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                final ok = await guard(ctx, () => _pos(ref).pay(num.tryParse(amount.text) ?? 0, method), success: 'Payment recorded');
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Record payment'),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _merge(BuildContext context, WidgetRef ref) async {
    final targets = ((data['mergeTargets'] as List?) ?? const []).cast<Json>();
    if (targets.isEmpty) {
      toast(context, 'No other open tables to merge with');
      return;
    }
    final into = await showModalBottomSheet<Json>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Merge this table into…', style: display(ctx, size: 20)),
          const SizedBox(height: 8),
          for (final t in targets)
            ListTile(leading: const Icon(Icons.table_restaurant_rounded), title: Text('Table ${t['number']}'), onTap: () => Navigator.pop(ctx, t)),
        ]),
      ),
    );
    if (into == null || !context.mounted) return;
    if (!await confirm(context, title: 'Merge into table ${into['number']}?', message: 'Orders and payments move across; this table goes to cleaning.')) return;
    if (!context.mounted) return;
    await guard(context, () => _pos(ref).mergeInto(into['sessionId'] as String), success: 'Merged into table ${into['number']}');
    ref.invalidate(floorProvider);
  }

  Future<void> _close(BuildContext context, WidgetRef ref, num remaining) async {
    var method = paymentMethods.first;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Close table', style: display(ctx, size: 22)),
            const SizedBox(height: 6),
            Text(remaining > 0 ? 'Collect the remaining ${money(remaining)} by:' : 'Bill is fully paid.', style: TextStyle(color: ctx.c.muted)),
            const SizedBox(height: 12),
            if (remaining > 0)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in paymentMethods) ChoiceChip(label: Text(m), selected: method == m, showCheckmark: false, onSelected: (_) => set(() => method = m)),
              ]),
            const SizedBox(height: 18),
            FilledButton(key: const Key('confirm-close'), onPressed: () => Navigator.pop(ctx, true), child: Text('Close & settle ${money(remaining > 0 ? remaining : 0)}')),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await guard(context, () => _pos(ref).close(method), success: 'Table closed — set to cleaning');
    ref.invalidate(floorProvider);
    if (done && context.mounted) Navigator.pop(context);
  }
}

/// Menu picker for POS: search + category, quantities, returns {menuItemId: qty}.
class _MenuPicker extends StatefulWidget {
  const _MenuPicker({required this.menu});
  final List<Json> menu;
  @override
  State<_MenuPicker> createState() => _MenuPickerState();
}

class _MenuPickerState extends State<_MenuPicker> {
  final Map<String, int> _qty = {};
  String _q = '';
  String _cat = 'All';

  @override
  Widget build(BuildContext context) {
    final cats = ['All', ...{for (final m in widget.menu) m['category'] as String}];
    final items = widget.menu
        .where((m) => (_cat == 'All' || m['category'] == _cat) && (m['name'] as String).toLowerCase().contains(_q.toLowerCase()))
        .toList();
    final total = _qty.entries.fold<num>(0, (s, e) => s + e.value * asNum(widget.menu.firstWhere((m) => m['id'] == e.key)['price']));
    final count = _qty.values.fold(0, (a, b) => a + b);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Search menu', prefixIcon: Icon(Icons.search_rounded))),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(c), selected: _cat == c, showCheckmark: false, onSelected: (_) => setState(() => _cat = c)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final m = items[i];
              final id = m['id'] as String;
              final q = _qty[id] ?? 0;
              return ListTile(
                leading: NetImage(m['imageUrl'] as String? ?? '', width: 46, height: 46, radius: 10),
                title: Text(m['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(money(asNum(m['price']))),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (q > 0)
                    IconButton(icon: const Icon(Icons.remove_circle_outline_rounded), onPressed: () => setState(() => q == 1 ? _qty.remove(id) : _qty[id] = q - 1)),
                  if (q > 0) Text('$q', style: const TextStyle(fontWeight: FontWeight.w800)),
                  IconButton(
                    key: Key('pick-${m['name']}'),
                    icon: Icon(Icons.add_circle_rounded, color: context.c.accent),
                    onPressed: () => setState(() => _qty[id] = q + 1),
                  ),
                ]),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              key: const Key('send-kot'),
              onPressed: count == 0 ? null : () => Navigator.pop(context, _qty),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(count == 0 ? 'Select items' : 'Send KOT · $count item${count == 1 ? '' : 's'} · ${money(total)}'),
            ),
          ),
        ),
      ]),
    );
  }
}
