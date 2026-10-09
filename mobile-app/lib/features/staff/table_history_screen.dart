import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'staff_providers.dart';

/// Session history for one table (last 30 days) — admin /table-history/[id].
class TableHistoryScreen extends ConsumerWidget {
  const TableHistoryScreen({super.key, required this.tableId});
  final String tableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Table history')),
      body: AsyncBody<Json>(
        value: ref.watch(tableHistoryProvider(tableId)),
        onRefresh: () async => ref.refresh(tableHistoryProvider(tableId).future),
        builder: (h) {
          final sessions = ((h['sessions'] as List?) ?? const []).cast<Json>();
          if (sessions.isEmpty) {
            return ListView(children: const [SizedBox(height: 80), EmptyState(icon: Icons.history_rounded, title: 'No sessions in the last 30 days')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = sessions[i];
              final items = ((s['items'] as List?) ?? const []).cast<Json>();
              return AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(fmtDateTime(s['openedAt']), style: const TextStyle(fontWeight: FontWeight.w800))),
                    StatusChip(s['status'] as String),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${s['customerCount']} guests · ${s['durationMinutes']} min${s['waiterName'] != null ? ' · ${s['waiterName']}' : ''}${s['paymentMethod'] != null ? ' · ${s['paymentMethod']}' : ''}',
                    style: TextStyle(color: context.c.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(items.map((it) => '${it['qty']}× ${it['name']}').join(', '), style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: Text(money(asNum(s['total'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
