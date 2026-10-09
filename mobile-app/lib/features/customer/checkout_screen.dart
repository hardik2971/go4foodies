import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'customer_providers.dart';
import 'menu_screen.dart';
import 'orders_screen.dart';
import 'payment_webview.dart';

/// Cart review → Take Away (now / scheduled) or table order → payment → place.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _schedule = 'NOW';
  DateTime _day = DateTime.now();
  String? _slot;
  String _pay = 'restaurant';
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    final cart = ref.read(cartProvider);
    final table = cart.table;
    if (table == null && _schedule == 'LATER' && _slot == null) {
      toast(context, 'Pick a pickup time', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      Json? payment;
      if (_pay != 'restaurant') {
        payment = await payOnline(context, ref, provider: _pay, amount: cart.total, description: 'Go4Foodie order');
        if (payment == null) return; // cancelled
      }
      final body = <String, dynamic>{
        'items': ref.read(cartProvider.notifier).payloadItems(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (payment != null) 'payment': payment else 'payAtRestaurant': true,
        if (table != null) ...{'type': 'DINE_IN', 'tableCode': table.code} else ...{
          'type': 'TAKE_AWAY',
          'scheduleType': _schedule,
          if (_schedule == 'LATER') ...{'scheduleDate': ymd(_day), 'scheduleTime': _slot},
        },
      };
      final res = await ref.read(apiProvider).post('/api/mobile/customer/orders', body);
      ref.read(cartProvider.notifier).clear(keepTable: table != null);
      ref.invalidate(myOrdersProvider);
      ref.invalidate(customerHomeProvider);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OrderPlacedScreen(orderId: res['id'] as String, number: res['number'] as String, table: table?.number),
      ));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final table = cart.table;
    final c = context.c;
    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your order')),
        body: EmptyState(icon: Icons.shopping_bag_outlined, title: 'Your cart is empty', action: 'Browse menu', onAction: () => Navigator.pop(context)),
      );
    }
    final days = List.generate(14, (i) => DateTime.now().add(Duration(days: i)));
    final slots = pickupSlots(_day);

    return Scaffold(
      appBar: AppBar(title: Text(table != null ? 'Table ${table.number}' : 'Checkout')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 140), children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(children: [
            for (final l in cart.lines.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  NetImage(l.item.imageUrl, width: 48, height: 48, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(money(l.item.price), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ]),
                  ),
                  QtyStepper(
                    qty: l.qty,
                    onAdd: () => ref.read(cartProvider.notifier).add(l.item),
                    onRemove: () => ref.read(cartProvider.notifier).remove(l.item.id),
                  ),
                ]),
              ),
          ]),
        ),
        if (table == null) ...[
          const SectionTitle('Pickup time', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'NOW', label: Text('As soon as possible'), icon: Icon(Icons.bolt_rounded)),
              ButtonSegment(value: 'LATER', label: Text('Schedule'), icon: Icon(Icons.schedule_rounded)),
            ],
            selected: {_schedule},
            onSelectionChanged: (s) => setState(() => _schedule = s.first),
          ),
          if (_schedule == 'NOW')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Ready in about 25 minutes — around ${DateFormat('h:mm a').format(DateTime.now().add(const Duration(minutes: 25)))}.',
                  style: TextStyle(color: c.muted)),
            ),
          if (_schedule == 'LATER') ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = days[i];
                  final sel = ymd(d) == ymd(_day);
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      _day = d;
                      _slot = null;
                    }),
                    child: Container(
                      width: 58,
                      decoration: BoxDecoration(
                        color: sel ? c.accent : c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sel ? c.accent : c.border),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(DateFormat('EEE').format(d), style: TextStyle(fontSize: 12, color: sel ? AppColors.ink : c.muted)),
                        Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: sel ? AppColors.ink : c.fg)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (slots.isEmpty)
              Text('No pickup slots left today — choose another day.', style: TextStyle(color: c.muted))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in slots)
                  ChoiceChip(label: Text(fmtSlot(s)), selected: _slot == s, showCheckmark: false, onSelected: (_) => setState(() => _slot = s)),
              ]),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppCard(
              color: c.accentSoft,
              child: Row(children: [
                Icon(Icons.room_service_rounded, color: c.accent),
                const SizedBox(width: 12),
                const Expanded(child: Text('Your order goes straight to the kitchen and is added to your table bill.')),
              ]),
            ),
          ),
        const SectionTitle('Notes', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
        TextField(controller: _notes, maxLines: 2, maxLength: 500, decoration: const InputDecoration(hintText: 'Allergies, special requests…')),
        const SectionTitle('Payment', padding: EdgeInsets.fromLTRB(4, 12, 4, 10)),
        PaymentOptions(value: _pay, onChanged: (v) => setState(() => _pay = v)),
      ]),
      bottomSheet: Container(
        color: c.surface,
        padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total', style: TextStyle(color: c.muted)),
            Text(money(cart.total), style: display(context, size: 24)),
          ]),
          const SizedBox(width: 20),
          Expanded(
            child: FilledButton(
              key: const Key('place-order'),
              onPressed: _busy ? null : _place,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink))
                  : Text(table != null ? 'Send to kitchen' : 'Place order'),
            ),
          ),
        ]),
      ),
    );
  }
}

class OrderPlacedScreen extends ConsumerWidget {
  const OrderPlacedScreen({super.key, required this.orderId, required this.number, this.table});
  final String orderId, number;
  final String? table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.goldSoft, AppColors.goldDeep])),
              child: const Icon(Icons.check_rounded, size: 46, color: AppColors.ink),
            ),
            const SizedBox(height: 24),
            Text(table != null ? 'Sent to the kitchen' : 'Order placed', style: display(context, size: 30)),
            const SizedBox(height: 10),
            Text('Order $number', style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              table != null ? 'Your dishes are on their way to table $table.' : "We'll have it ready for pickup. A confirmation is on its way to your email.",
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId))),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Track order'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Back to menu'),
            ),
          ]),
        ),
      ),
    );
  }
}
