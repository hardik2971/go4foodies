import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../customer/orders_screen.dart' show orderTypeLabel;
import 'staff_providers.dart';

const _flow = ['PENDING', 'PREPARING', 'READY', 'COMPLETED'];

String? nextOrderStatus(String s) {
  final i = _flow.indexOf(s);
  return i >= 0 && i < _flow.length - 1 ? _flow[i + 1] : null;
}

/// Kitchen / service order board (admin /orders) — POS, website and app
/// orders in one live list, advanced PENDING → PREPARING → READY → COMPLETED.
class OrdersBoardScreen extends ConsumerStatefulWidget {
  const OrdersBoardScreen({super.key});
  @override
  ConsumerState<OrdersBoardScreen> createState() => _OrdersBoardScreenState();
}

class _OrdersBoardScreenState extends ConsumerState<OrdersBoardScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => ref.invalidate(staffOrdersProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const ['Active', 'Pending', 'Preparing', 'Ready', 'Done'];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in tabs) Tab(text: t)]),
        ),
        body: AsyncBody<List<Json>>(
          value: ref.watch(staffOrdersProvider),
          onRefresh: () async => ref.refresh(staffOrdersProvider.future),
          builder: (orders) {
            List<Json> by(bool Function(String) f) => orders.where((o) => f(o['status'] as String)).toList();
            final lists = [
              by((s) => s == 'PENDING' || s == 'PREPARING' || s == 'READY'),
              by((s) => s == 'PENDING'),
              by((s) => s == 'PREPARING'),
              by((s) => s == 'READY'),
              by((s) => s == 'COMPLETED' || s == 'CANCELED'),
            ];
            return TabBarView(children: [for (final l in lists) _OrderList(orders: l)]);
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});
  final List<Json> orders;
  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return ListView(children: const [SizedBox(height: 60), EmptyState(icon: Icons.check_circle_outline_rounded, title: 'All clear', message: 'No orders here right now.')]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => StaffOrderCard(order: orders[i]),
    );
  }
}

class StaffOrderCard extends ConsumerWidget {
  const StaffOrderCard({super.key, required this.order});
  final Json order;

  Future<void> _set(BuildContext context, WidgetRef ref, String status) => guard(context, () async {
        await ref.read(apiProvider).patch('$staffApi/orders/${order['id']}/status', {'status': status});
        ref.invalidate(staffOrdersProvider);
      }, success: '${order['number']} → ${humanize(status)}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final status = order['status'] as String;
    final next = nextOrderStatus(status);
    final items = ((order['items'] as List?) ?? const []).cast<Json>();
    final online = order['channel'] == 'ONLINE';
    final when = order['scheduleType'] == 'LATER' ? 'Pickup ${fmtDate(order['scheduleDate'], 'd MMM')} ${fmtSlot(order['scheduleTime'] as String?)}' : ago(order['createdAt']);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(order['number'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(width: 8),
          if (online)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: c.info.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
              child: Text('ONLINE', style: TextStyle(color: c.info, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          const Spacer(),
          StatusChip(status),
        ]),
        const SizedBox(height: 4),
        Text(
          '${order['tableNumber'] != null ? 'Table ${order['tableNumber']}' : orderTypeLabel(order['type'] as String?)} · ${order['customer']} · $when',
          style: TextStyle(color: c.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              Container(
                width: 26,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(6)),
                child: Text('${it['qty']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(it['name'] as String)),
            ]),
          ),
        if ((order['notes'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text('“${order['notes']}”', style: TextStyle(color: c.warn, fontStyle: FontStyle.italic, fontSize: 12.5)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Text(money(asNum(order['total'])), style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          if (status != 'COMPLETED' && status != 'CANCELED')
            TextButton(
              onPressed: () async {
                if (await confirm(context, title: 'Cancel ${order['number']}?', confirmLabel: 'Cancel order', destructive: true) && context.mounted) {
                  await _set(context, ref, 'CANCELED');
                }
              },
              style: TextButton.styleFrom(foregroundColor: c.danger),
              child: const Text('Cancel'),
            ),
          if (next != null) ...[
            const SizedBox(width: 6),
            FilledButton(
              key: Key('advance-${order['number']}'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
              onPressed: () => _set(context, ref, next),
              child: Text(next == 'PREPARING' ? 'Start' : next == 'READY' ? 'Mark ready' : 'Complete'),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Small pending-count badge helper for nav bars.
final pendingOrdersCountProvider = Provider.autoDispose<int>((ref) {
  final orders = ref.watch(staffOrdersProvider).valueOrNull ?? const [];
  return orders.where((o) => o['status'] == 'PENDING').length;
});

bool canAll(Profile? p, List<String> actions) => p != null && actions.every(p.can);
