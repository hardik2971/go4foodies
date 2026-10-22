import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/ops_widgets.dart';
import '../widgets/ui.dart';

/// Orders — port of resources/views/orders/index.blade.php (OrdersManager).
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => asJson(await Api.get('/orders')),
        builder: (context, data, _) => _OrdersView(orders: asJsonList(data['orders'])),
      );
}

const _orderFlow = ['PENDING', 'PREPARING', 'READY', 'COMPLETED'];
const _typeLabels = {'DINE_IN': 'Dine-in', 'DELIVERY': 'Delivery', 'PICKUP': 'Pick-up'};
const _statusLabels = {'PENDING': 'Pending', 'PREPARING': 'Preparing', 'READY': 'Ready', 'COMPLETED': 'Completed', 'CANCELED': 'Canceled'};
const _statusFilters = ['ALL', ..._orderFlow, 'CANCELED'];

String _gatewayLabel(dynamic p) => p == 'stripe' ? 'Stripe' : (p == 'paypal' ? 'PayPal' : 'Razorpay');

class _OrdersView extends StatefulWidget {
  const _OrdersView({required this.orders});
  final List<Json> orders;
  @override
  State<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<_OrdersView> {
  late List<Json> orders = widget.orders;
  String status = 'ALL', type = 'ALL', channel = 'ALL', query = '';
  Json? active;
  final rev = Rev();

  @override
  void dispose() {
    rev.dispose();
    super.dispose();
  }

  void update(VoidCallback fn) {
    setState(fn);
    rev.bump();
  }

  List<Json> get filtered {
    final q = query.trim().toLowerCase();
    return orders
        .where((o) =>
            (status == 'ALL' || o['status'] == status) &&
            (type == 'ALL' || o['type'] == type) &&
            (channel == 'ALL' || o['channel'] == channel) &&
            (q.isEmpty || str(o['number']).toLowerCase().contains(q) || str(o['customer']).toLowerCase().contains(q)))
        .toList();
  }

  List<String> nextStatuses(String st) {
    if (st == 'COMPLETED' || st == 'CANCELED') return [];
    final idx = _orderFlow.indexOf(st);
    final forward = idx >= 0 && idx < _orderFlow.length - 1 ? [_orderFlow[idx + 1]] : <String>[];
    return [...forward, 'CANCELED'];
  }

  void changeStatus(String id, String next) {
    update(() {
      orders = [for (final o in orders) o['id'] == id ? {...o, 'status': next} : o];
      if (active != null && active!['id'] == id) active = {...active!, 'status': next};
    });
    guard(() => Api.patch('/orders/$id/status', {'status': next}));
  }

  Future<void> open(Json o) async {
    active = o;
    await showAppModal(context, title: str(o['number']), builder: (ctx) => synced(rev, () => active == null ? const SizedBox() : _detail(ctx, active!)));
    if (mounted) setState(() => active = null);
  }

  Widget statusBadge(String st) => toneBadge(context, st, _statusLabels[st] ?? st, dot: true);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final completed = orders.where((o) => o['status'] == 'COMPLETED');
    final rows = filtered;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TileGrid(minWidth: 160, children: [
        StatTile(icon: LucideIcons.receipt, label: 'Total Orders', value: '${orders.length}'),
        StatTile(icon: LucideIcons.circleCheck, label: 'Completed', value: '${completed.length}'),
        StatTile(icon: LucideIcons.circleX, label: 'Canceled', value: '${orders.where((o) => o['status'] == 'CANCELED').length}'),
        StatTile(icon: LucideIcons.dollarSign, label: 'Revenue', value: money(completed.fold<num>(0, (s, o) => s + toNum(o['total'])))),
      ]),
      const SizedBox(height: 20),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        FilterPills<String>(
          options: _statusFilters,
          value: status,
          label: (s) => s == 'ALL' ? 'All' : _statusLabels[s]!,
          onChanged: (v) => setState(() => status = v),
        ),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          AppSelect<String>(
            value: channel,
            items: const [('ALL', 'All channels'), ('ONLINE', 'Online'), ('POS', 'In-house (POS)')],
            onChanged: (v) => setState(() => channel = v),
          ),
          AppSelect<String>(
            value: type,
            items: const [('ALL', 'All types'), ('DINE_IN', 'Dine-in'), ('DELIVERY', 'Delivery'), ('PICKUP', 'Pick-up')],
            onChanged: (v) => setState(() => type = v),
          ),
          SearchField(hint: 'Search order # or customer…', width: 224, onChanged: (v) => setState(() => query = v)),
        ]),
      ]),
      const SizedBox(height: 20),
      DataTableCard(
        columns: const [
          DataCol('Order', flex: 3),
          DataCol('Customer', flex: 2),
          DataCol('Type'),
          DataCol('Items'),
          DataCol('Total'),
          DataCol('Time'),
          DataCol('Status', flex: 2),
          DataCol('View', align: TextAlign.right),
        ],
        empty: 'No orders match your filters.',
        onRowTap: (i) => open(rows[i]),
        rows: [
          for (final o in rows)
            [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(str(o['number']), style: const TextStyle(fontWeight: FontWeight.w500)),
                // text-gold-deep is an undefined token in the original → default text colour.
                if (has(o['tableNumber'])) TinyPill('Table ${o['tableNumber']}', fg: c.fg, bg: c.gold.withValues(alpha: .15)),
                if (o['channel'] == 'ONLINE') TinyPill('Online', fg: c.accent, bg: c.accentSoft),
                if (has(o['paymentProvider'])) TinyPill(_gatewayLabel(o['paymentProvider']), fg: gatewayBlue, bg: gatewayBlue.withValues(alpha: .15)),
              ]),
              Text(str(o['customer'])),
              Muted(_typeLabels[o['type']] ?? '', size: 14),
              Muted('${asJsonList(o['items']).fold<num>(0, (s, it) => s + toNum(it['qty']))}', size: 14),
              Text(money(o['total']), style: const TextStyle(fontWeight: FontWeight.w500)),
              Muted(fmtDate(o['createdAt'], 'h:mm a'), size: 14),
              statusBadge(str(o['status'])),
              Padding(padding: const EdgeInsets.all(8), child: Icon(LucideIcons.eye, size: 16, color: c.fgMuted)),
            ],
        ],
        footer: 'Showing ${rows.length} of ${orders.length} orders. Status changes are in-session until the MySQL data layer is connected.',
      ),
    ]);
  }

  Widget _detail(BuildContext ctx, Json o) {
    final c = ctx.c;
    final st = str(o['status']);
    final flowIndex = st == 'CANCELED' ? -1 : _orderFlow.indexOf(st);
    final details = <(String, String)>[
      ('Customer', str(o['customer'])),
      ('Type', _typeLabels[o['type']] ?? ''),
      if (has(o['tableNumber'])) ('Table', 'Table ${o['tableNumber']}'),
      ('Outlet', str(o['outlet'])),
      ('Payment', str(o['paymentMethod'])),
      if (has(o['customerPhone'])) ('Phone', str(o['customerPhone'])),
      if (has(o['customerEmail'])) ('Email', str(o['customerEmail'])),
      if (has(o['razorpayPaymentId'])) ('${_gatewayLabel(o['paymentProvider'])} Payment', str(o['razorpayPaymentId'])),
    ];
    final next = nextStatuses(st);
    final items = asJsonList(o['items']);
    const gap = SizedBox(height: 20);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        statusBadge(st),
        if (o['channel'] == 'ONLINE') ...[const SizedBox(width: 8), TinyPill('Online', fg: c.accent, bg: c.accentSoft, uppercase: false, size: 12)],
        if (has(o['paymentProvider'])) ...[
          const SizedBox(width: 8),
          TinyPill(_gatewayLabel(o['paymentProvider']), fg: gatewayBlue, bg: gatewayBlue.withValues(alpha: .15), uppercase: false, size: 12),
        ],
        const Spacer(),
        Muted(fmtDate(o['createdAt'], 'MMM d, h:mm a'), size: 14),
      ]),
      gap,
      Boxed(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FlowStepper(labels: [for (final s in _orderFlow) _statusLabels[s]!], current: flowIndex),
          if (st == 'CANCELED') const DangerNote('This order was canceled.'),
        ]),
      ),
      gap,
      TwoCol(stretch: true, children: [for (final d in details) DetailBox(d.$1, d.$2)]),
      if (has(o['scheduleType'])) ...[
        gap,
        Boxed(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          radius: 8,
          color: c.accentSoft.withValues(alpha: .5),
          borderColor: c.accent.withValues(alpha: .3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${o['scheduleType'] == 'LATER' ? 'Scheduled' : 'ASAP'} pickup'.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .6, color: c.accent)),
            const SizedBox(height: 2),
            Text(
              o['scheduleType'] == 'LATER' && has(o['scheduleDate'])
                  ? fmtDate(o['scheduleDate'], 'EEE, MMM d') + (has(o['scheduleTime']) ? ' · ${o['scheduleTime']}' : '')
                  : 'As soon as possible',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ],
      if (has(o['notes'])) ...[
        gap,
        Boxed(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          radius: 8,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Muted('Notes', size: 12),
            const SizedBox(height: 2),
            Text(str(o['notes']), style: const TextStyle(fontSize: 14)),
          ]),
        ),
      ],
      gap,
      Boxed(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
            child: const Caption('Items', bottom: 0),
          ),
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
              child: Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(style: const TextStyle(fontSize: 14), children: [
                    TextSpan(text: '${items[i]['qty']}×', style: const TextStyle(fontWeight: FontWeight.w500)),
                    TextSpan(text: ' ${items[i]['name']}'),
                  ])),
                ),
                Muted(money(toNum(items[i]['qty']) * toNum(items[i]['price'])), size: 14),
              ]),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              Text(money(o['total']), style: display(ctx, size: 18)),
            ]),
          ),
        ]),
      ),
      gap,
      if (next.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Caption('Update status'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in next)
              Btn('Mark ${_statusLabels[s]}', kind: s == 'CANCELED' ? BtnKind.dangerOutline : BtnKind.primary, onPressed: () => changeStatus(str(o['id']), s)),
          ]),
        ])
      else
        Muted('This order is ${_statusLabels[st] ?? st} — no further actions.', size: 14),
    ]);
  }
}
