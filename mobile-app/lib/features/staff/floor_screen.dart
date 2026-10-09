import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'pos_screen.dart';
import 'staff_providers.dart';

Color stateColor(BuildContext context, String s) => StatusChip.colorFor(context, s);

/// Live floor plan — every table with its state and running bill. Polls the
/// admin every 8 s (same data as the web floor plan's SSE refresh).
class FloorScreen extends ConsumerStatefulWidget {
  const FloorScreen({super.key});
  @override
  ConsumerState<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends ConsumerState<FloorScreen> {
  Timer? _poll;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => ref.invalidate(floorProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: context.c.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Live', style: TextStyle(color: context.c.success, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
      body: AsyncBody<Json>(
        value: ref.watch(floorProvider),
        onRefresh: () async => ref.refresh(floorProvider.future),
        builder: (data) {
          final tables = ((data['tables'] as List?) ?? const []).cast<Json>();
          final counts = <String, int>{for (final s in tableStates) s: tables.where((t) => t['state'] == s).length};
          final shown = _filter == 'ALL' ? tables : tables.where((t) => t['state'] == _filter).toList();
          if (tables.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              EmptyState(icon: Icons.table_restaurant_outlined, title: 'No tables yet', message: 'Add tables in the admin (Tables) or the Owner app.'),
            ]);
          }
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(label: 'All', count: tables.length, selected: _filter == 'ALL', onTap: () => setState(() => _filter = 'ALL')),
                    for (final s in tableStates)
                      if (counts[s]! > 0)
                        _FilterChip(
                          label: humanize(s),
                          count: counts[s]!,
                          color: stateColor(context, s),
                          selected: _filter == s,
                          onTap: () => setState(() => _filter = s),
                        ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TableCard(table: shown[i]),
                  childCount: shown.length,
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap, this.color});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          showCheckmark: false,
          selected: selected,
          onSelected: (_) => onTap(),
          avatar: color == null ? null : CircleAvatar(backgroundColor: color, radius: 5),
          label: Text('$label  $count'),
        ),
      );
}

class _TableCard extends ConsumerWidget {
  const _TableCard({required this.table});
  final Json table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = table['state'] as String;
    final color = stateColor(context, state);
    final session = table['session'] as Json?;
    final c = context.c;
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: color.withValues(alpha: 0.45))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('table-${table['number']}'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PosScreen(tableId: table['id'] as String))),
        onLongPress: () => showTableStateSheet(context, ref, table),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('T${table['number']}', style: display(context, size: 24)),
              const Spacer(),
              Icon(Icons.chair_alt_rounded, size: 15, color: c.muted),
              Text(' ${table['capacity']}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
            ]),
            if ((table['name'] as String?)?.isNotEmpty == true)
              Text(table['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12)),
            const Spacer(),
            if (session != null) ...[
              Text(money(asNum(session['currentBill'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 2),
              Text(
                '${session['customerCount']} guests · ${ago(session['openedAt']).replaceAll(' ago', '')}${session['waiterName'] != null ? ' · ${session['waiterName']}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            StatusChip(state),
          ]),
        ),
      ),
    );
  }
}

Future<void> showTableStateSheet(BuildContext context, WidgetRef ref, Json table) async {
  final profile = ref.read(sessionProvider).profile;
  if (profile?.can('operate:floor') != true) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Table ${table['number']} state', style: display(ctx, size: 20)),
        const SizedBox(height: 8),
        for (final s in tableStates)
          ListTile(
            leading: CircleAvatar(radius: 6, backgroundColor: stateColor(ctx, s)),
            title: Text(humanize(s)),
            trailing: table['state'] == s ? Icon(Icons.check_rounded, color: ctx.c.accent) : null,
            onTap: () async {
              Navigator.pop(ctx);
              await guard(context, () async {
                await ref.read(apiProvider).patch('$staffApi/tables/${table['id']}/state', {'state': s});
                ref.invalidate(floorProvider);
              }, success: 'Table ${table['number']} → ${humanize(s)}');
            },
          ),
      ]),
    ),
  );
}
