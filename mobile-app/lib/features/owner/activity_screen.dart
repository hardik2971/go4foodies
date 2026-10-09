import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../staff/staff_providers.dart';

/// Alerts (admin /notifications) + audit trail (admin /audit, owner only).
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAudit = ref.watch(sessionProvider).profile?.can('manage:settings') == true;
    return DefaultTabController(
      length: showAudit ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity'),
          bottom: showAudit ? const TabBar(tabs: [Tab(text: 'Alerts'), Tab(text: 'Audit log')]) : null,
        ),
        body: showAudit ? const TabBarView(children: [_Alerts(), _Audit()]) : const _Alerts(),
      ),
    );
  }
}

class _Alerts extends ConsumerWidget {
  const _Alerts();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<List<Json>>(
      value: ref.watch(notificationsProvider),
      onRefresh: () async => ref.refresh(notificationsProvider.future),
      builder: (list) => list.isEmpty
          ? ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.notifications_off_outlined, title: 'You’re all caught up')])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = list[i];
                final (icon, color) = switch (n['type']) {
                  'order' => (Icons.receipt_long_rounded, context.c.accent),
                  'reservation' => (Icons.event_rounded, context.c.info),
                  'stock' => (Icons.inventory_2_rounded, context.c.warn),
                  _ => (Icons.table_restaurant_rounded, context.c.danger),
                };
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(n['detail'] as String, style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                      ]),
                    ),
                    Text(ago(n['time']), style: TextStyle(color: context.c.muted, fontSize: 11.5)),
                  ]),
                );
              },
            ),
    );
  }
}

class _Audit extends ConsumerWidget {
  const _Audit();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<List<Json>>(
      value: ref.watch(auditProvider),
      onRefresh: () async => ref.refresh(auditProvider.future),
      builder: (list) => list.isEmpty
          ? ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.fact_check_outlined, title: 'No audit entries yet')])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = list[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(Icons.history_toggle_off_rounded, color: context.c.accent),
                  title: Text('${a['action']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('${a['userName'] ?? 'System'}${a['detail'] != null ? ' · ${a['detail']}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(fmtDateTime(a['createdAt']), style: TextStyle(color: context.c.muted, fontSize: 11)),
                );
              },
            ),
    );
  }
}
