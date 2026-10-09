import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'customer_providers.dart';

String orderTypeLabel(String? t) => switch (t) {
      'PICKUP' => 'Take away',
      'DINE_IN' => 'Dine-in',
      'DELIVERY' => 'Delivery',
      _ => humanize(t),
    };

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: AsyncBody<List<Json>>(
        value: ref.watch(myOrdersProvider),
        onRefresh: () async => ref.refresh(myOrdersProvider.future),
        builder: (orders) => orders.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet', message: 'Your take-away and table orders will appear here.'),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => OrderTile(order: orders[i]),
              ),
      ),
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});
  final Json order;

  @override
  Widget build(BuildContext context) {
    final items = ((order['items'] as List?) ?? const []).cast<Json>();
    final summary = items.map((i) => '${i['qty']}× ${i['name']}').join(', ');
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'] as String))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(order['type'] == 'DINE_IN' ? Icons.table_restaurant_rounded : Icons.shopping_bag_rounded, size: 18, color: context.c.accent),
          const SizedBox(width: 8),
          Text(order['number'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          StatusChip(order['status'] as String),
        ]),
        const SizedBox(height: 8),
        Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.c.muted)),
        const SizedBox(height: 10),
        Row(children: [
          Text(
            order['type'] == 'DINE_IN' ? 'Table ${order['tableNumber'] ?? ''} · ${ago(order['createdAt'])}' : '${orderTypeLabel(order['type'] as String?)} · ${ago(order['createdAt'])}',
            style: TextStyle(color: context.c.muted, fontSize: 12.5),
          ),
          const Spacer(),
          Text(money(asNum(order['total'])), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}

/// Live order tracking — polls every 10s while the order is in progress.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;
  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      final status = ref.read(orderDetailProvider(widget.orderId)).valueOrNull?['status'];
      if (status == 'COMPLETED' || status == 'CANCELED') return;
      ref.invalidate(orderDetailProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: AsyncBody<Json>(
        value: ref.watch(orderDetailProvider(widget.orderId)),
        onRefresh: () async => ref.refresh(orderDetailProvider(widget.orderId).future),
        builder: (o) {
          final items = ((o['items'] as List?) ?? const []).cast<Json>();
          final status = o['status'] as String;
          final session = o['session'] as Json?;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(o['number'] as String, style: display(context, size: 24))),
                  StatusChip(status),
                ]),
                const SizedBox(height: 6),
                Text(
                  o['type'] == 'DINE_IN'
                      ? 'Dine-in · Table ${o['tableNumber'] ?? ''} · ${fmtDateTime(o['createdAt'])}'
                      : '${orderTypeLabel(o['type'] as String?)} · ${fmtDateTime(o['createdAt'])}',
                  style: TextStyle(color: c.muted),
                ),
                if (o['type'] == 'PICKUP' && status != 'COMPLETED' && status != 'CANCELED') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.schedule_rounded, color: c.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          o['scheduleType'] == 'LATER'
                              ? 'Pickup ${fmtDate(o['scheduleDate'])} at ${fmtSlot(o['scheduleTime'] as String?)}'
                              : 'Estimated pickup around ${fmtTime(o['estimatedPickup'])}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 14),
            if (status != 'CANCELED') _Timeline(status: status, dineIn: o['type'] == 'DINE_IN'),
            if (status == 'CANCELED')
              AppCard(
                color: c.danger.withValues(alpha: 0.1),
                child: Text('This order was cancelled by the restaurant.', style: TextStyle(color: c.danger, fontWeight: FontWeight.w700)),
              ),
            const SectionTitle('Items', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
            AppCard(
              child: Column(children: [
                for (final i in items)
                  KeyValue('${i['qty']} × ${i['name']}', money(asNum(i['price']) * asNum(i['qty']))),
                const Divider(height: 20),
                KeyValue('Total', money(asNum(o['total'])), bold: true),
                KeyValue('Payment', o['paid'] == true ? 'Paid online${o['paymentProvider'] != null ? ' (${humanize(o['paymentProvider'] as String)})' : ''}' : 'Pay at restaurant'),
              ]),
            ),
            if (session != null) ...[
              const SectionTitle('Table bill', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
              AppCard(
                child: Column(children: [
                  KeyValue('Bill total', money(asNum(session['total']))),
                  KeyValue('Paid', money(asNum(session['paid']))),
                  KeyValue('Remaining', money(asNum(session['remaining'])), bold: true),
                  const SizedBox(height: 6),
                  Text(session['status'] == 'CLOSED' ? 'Your table has been settled. Thank you!' : 'Your server will settle the bill at your table.',
                      style: TextStyle(color: c.muted, fontSize: 12.5)),
                ]),
              ),
            ],
            if (o['notes'] != null) ...[
              const SectionTitle('Notes', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
              AppCard(child: Text(o['notes'] as String)),
            ],
          ]);
        },
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status, required this.dineIn});
  final String status;
  final bool dineIn;

  @override
  Widget build(BuildContext context) {
    const flow = ['PENDING', 'PREPARING', 'READY', 'COMPLETED'];
    final labels = {
      'PENDING': ('Order received', 'The restaurant has your order'),
      'PREPARING': ('Preparing', 'Our chefs are cooking'),
      'READY': (dineIn ? 'Ready to serve' : 'Ready for pickup', dineIn ? 'On its way to your table' : 'Head to the counter'),
      'COMPLETED': ('Completed', 'Enjoy your meal!'),
    };
    final current = flow.indexOf(status);
    final c = context.c;
    return AppCard(
      child: Column(children: [
        for (var i = 0; i < flow.length; i++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(shape: BoxShape.circle, color: i <= current ? c.accent : c.surface2, border: Border.all(color: i <= current ? c.accent : c.border)),
                child: i <= current ? const Icon(Icons.check_rounded, size: 16, color: AppColors.ink) : null,
              ),
              if (i < flow.length - 1) Container(width: 2, height: 30, color: i < current ? c.accent : c.border),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(labels[flow[i]]!.$1, style: TextStyle(fontWeight: FontWeight.w700, color: i <= current ? c.fg : c.muted)),
                  Text(labels[flow[i]]!.$2, style: TextStyle(fontSize: 12.5, color: c.muted)),
                ]),
              ),
            ),
          ]),
      ]),
    );
  }
}
