import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/ops_widgets.dart';
import '../widgets/ui.dart';

/// POS — port of resources/views/pos/show.blade.php (PosScreen: open form + active session).
class PosPage extends StatelessWidget {
  const PosPage({super.key, required this.tableId});
  final String tableId;
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => asJson(await Api.get('/pos/$tableId')),
        builder: (context, data, _) => _PosView(data: data),
      );
}

const _printCss = '''
body{font-family:'Courier New',monospace;font-size:13px;padding:16px;color:#000;width:320px;margin:0 auto}
h1{font-size:16px;text-align:center;margin:0 0 2px} .muted{color:#555;font-size:11px;text-align:center;margin:0 0 8px}
table{width:100%;border-collapse:collapse} td{padding:2px 0;vertical-align:top} .r{text-align:right;white-space:nowrap}
.sep{border-top:1px dashed #000;margin:8px 0} .row{display:flex;justify-content:space-between} .big{font-weight:bold;font-size:15px}
''';

class _PosView extends StatefulWidget {
  const _PosView({required this.data});
  final Json data;
  @override
  State<_PosView> createState() => _PosViewState();
}

class _PosViewState extends State<_PosView> {
  late Json table = asJson(widget.data['table']);
  late Json? session = widget.data['session'] == null ? null : asJson(widget.data['session']);
  late final List<Json> menu = asJsonList(widget.data['menu']);
  late final List<Json> waiters = asJsonList(widget.data['waiters']);
  late List<Json> mergeTargets = asJsonList(widget.data['mergeTargets']);
  late final List<String> paymentMethods = List<String>.from((widget.data['paymentMethods'] as List?) ?? const ['Cash', 'Credit Card', 'Debit Card', 'UPI', 'Wallet', 'Mixed']);

  bool pending = false;
  // open-table form
  final guests = TextEditingController(text: '2'), custName = TextEditingController();
  String waiterId = '';
  // active session
  String query = '', cat = 'All', mergeId = '';
  Map<String, int> cart = {};
  final discount = TextEditingController(text: '0'), tax = TextEditingController(text: '0');
  final service = TextEditingController(text: '0'), tip = TextEditingController(text: '0');
  final payAmount = TextEditingController();
  late String payMethod = paymentMethods.first, payMethod2 = paymentMethods.first;

  @override
  void initState() {
    super.initState();
    if (session != null) seedBilling();
  }

  @override
  void dispose() {
    for (final c in [guests, custName, discount, tax, service, tip, payAmount]) {
      c.dispose();
    }
    super.dispose();
  }

  String get tableId => str(table['id']);

  void seedBilling() {
    final s = session!;
    discount.text = jsNum(s['discount'] ?? 0);
    tax.text = jsNum(s['tax'] ?? 0);
    service.text = jsNum(s['serviceCharge'] ?? 0);
    tip.text = jsNum(s['tip'] ?? 0);
  }

  List<Json> get available => menu.where((m) => m['available'] == true).toList();
  List<String> get cats => ['All', ...{for (final m in available) str(m['category'])}];
  List<Json> get filtered {
    final q = query.trim().toLowerCase();
    return available.where((m) => (cat == 'All' || m['category'] == cat) && (q.isEmpty || str(m['name']).toLowerCase().contains(q))).toList();
  }

  List<Json> get cartLines => [
        for (final m in available)
          if ((cart[m['id']] ?? 0) > 0) {'menuItemId': m['id'], 'name': m['name'], 'qty': cart[m['id']], 'price': m['price']},
      ];
  num get cartTotal => cartLines.fold<num>(0, (s, l) => s + toNum(l['qty']) * toNum(l['price']));
  int get cartCount => cartLines.fold<int>(0, (s, l) => s + (l['qty'] as int));

  ({num discount, num tax, num serviceCharge, num tip}) billing() =>
      (discount: toNum(discount.text), tax: toNum(tax.text), serviceCharge: toNum(service.text), tip: toNum(tip.text));
  Map<String, num> billingJson() {
    final b = billing();
    return {'discount': b.discount, 'tax': b.tax, 'serviceCharge': b.serviceCharge, 'tip': b.tip};
  }

  num get previewTotal {
    final b = billing();
    return math.max(0, toNum(session?['subtotal']) - b.discount + b.tax + b.serviceCharge + b.tip);
  }

  void add(String id) => setState(() => cart = {...cart, id: (cart[id] ?? 0) + 1});
  void sub(String id) => setState(() {
        final next = {...cart};
        final q = (next[id] ?? 0) - 1;
        if (q <= 0) {
          next.remove(id);
        } else {
          next[id] = q;
        }
        cart = next;
      });

  void apply(dynamic raw) {
    final res = asJson(raw);
    final had = session != null;
    setState(() {
      if (res['table'] != null) table = asJson(res['table']);
      session = res['session'] == null ? null : asJson(res['session']);
      if (res['mergeTargets'] != null) mergeTargets = asJsonList(res['mergeTargets']);
      if (!had && session != null) seedBilling();
    });
  }

  /// router.refresh(): reload the live session; errors are toasted.
  Future<void> run(String url, String method, [Map<String, dynamic>? body]) async {
    setState(() => pending = true);
    final payload = {'tableId': tableId, ...?body};
    try {
      apply(method == 'PATCH' ? await Api.patch(url, payload) : await Api.post(url, payload));
    } catch (e) {
      toast('$e', error: true);
      try {
        apply(await Api.get('/pos/$tableId/data'));
      } catch (_) {/* ignore */}
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  Future<void> openTable() {
    final g = guests.text.trim();
    return run('/pos/$tableId/open', 'POST', {
      'customerCount': int.tryParse(g) ?? g,
      'waiterId': waiterId.isEmpty ? null : waiterId,
      'customerName': custName.text.isEmpty ? null : custName.text,
    });
  }

  Future<void> line(String menuItemId, int delta) => delta == 1
      ? run('/pos/sessions/${session!['id']}/orders', 'POST', {
          'items': [
            {'menuItemId': menuItemId, 'qty': 1},
          ],
        })
      : run('/pos/sessions/${session!['id']}/decrement', 'POST', {'menuItemId': menuItemId});

  Future<void> doMerge() async {
    if (mergeId.isEmpty) return;
    final from = mergeId;
    setState(() => mergeId = '');
    await run('/pos/sessions/${session!['id']}/merge', 'POST', {'fromSessionId': from});
  }

  Future<void> doAddPayment() async {
    final amt = num.tryParse(payAmount.text.trim()) ?? 0;
    if (!(amt > 0)) return;
    await run('/pos/sessions/${session!['id']}/payments', 'POST', {'amount': amt, 'method': payMethod2});
    payAmount.text = '';
  }

  Future<void> sendToKitchen() async {
    if (cartCount == 0) return;
    final lines = cartLines;
    final items = [for (final l in lines) {'menuItemId': l['menuItemId'], 'qty': l['qty']}];
    printDoc('KOT', kotHtml(lines));
    await run('/pos/sessions/${session!['id']}/orders', 'POST', {'items': items});
    if (mounted) setState(() => cart = {});
  }

  Future<void> saveBilling() => run('/pos/sessions/${session!['id']}/billing', 'PATCH', billingJson());

  Future<void> closeAndPay() async {
    setState(() => pending = true);
    try {
      await Api.post('/pos/sessions/${session!['id']}/close', {...billingJson(), 'paymentMethod': payMethod});
    } catch (e) {
      toast('$e', error: true);
    }
    if (mounted) context.go('/floor');
  }

  // ---------------------------------------------------------------- print documents

  void printDoc(String title, String inner) => printHtml(
        '<!doctype html><html><head><title>${esc(title)}</title><style>$_printCss</style></head><body>$inner'
        '<script>window.onload=function(){window.focus();window.print()}</script></body></html>',
        width: 400,
        height: 680,
      );

  String kotHtml(List<Json> lines) {
    final rows = lines.map((l) => '<tr><td>${l['qty']} ×</td><td>${esc(l['name'])}</td></tr>').join();
    final time = DateFormat('h:mm:ss a', 'en_US').format(DateTime.now());
    return '<h1>KITCHEN ORDER</h1><p class="muted">Table ${esc(table['number'])} · $time</p>'
        '<div class="sep"></div><table>$rows</table>';
  }

  void printInvoice() {
    final s = session!;
    final b = billing();
    final rows = asJsonList(s['lines']).map((l) => '<tr><td>${l['qty']} × ${esc(l['name'])}</td><td class="r">${money(toNum(l['qty']) * toNum(l['price']))}</td></tr>').join();
    final when = DateFormat('M/d/yyyy, h:mm:ss a', 'en_US').format(DateTime.now());
    printDoc(
      'Invoice',
      '<h1>Go4Foodie</h1><p class="muted">Table ${esc(table['number'])} · $when</p>'
          '<div class="sep"></div><table>$rows</table><div class="sep"></div>'
          '<div class="row"><span>Subtotal</span><span>${money(s['subtotal'])}</span></div>'
          '${b.discount != 0 ? '<div class="row"><span>Discount</span><span>-${money(b.discount)}</span></div>' : ''}'
          '${b.tax != 0 ? '<div class="row"><span>Tax</span><span>${money(b.tax)}</span></div>' : ''}'
          '${b.serviceCharge != 0 ? '<div class="row"><span>Service</span><span>${money(b.serviceCharge)}</span></div>' : ''}'
          '${b.tip != 0 ? '<div class="row"><span>Tip</span><span>${money(b.tip)}</span></div>' : ''}'
          '<div class="sep"></div><div class="row big"><span>TOTAL</span><span>${money(previewTotal)}</span></div>',
    );
  }

  // ---------------------------------------------------------------- UI

  Widget backLink() => LinkBtn('Back to floor', icon: LucideIcons.arrowLeft, size: 14, onTap: () => context.go('/floor'));

  @override
  Widget build(BuildContext context) => session == null ? _openForm() : _active();

  Widget _openForm() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(alignment: Alignment.centerLeft, child: backLink()),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Open Table ${table['number']}', style: display(context, size: 20)),
              const SizedBox(height: 4),
              Muted('Seat guests to start a session.', size: 14),
              const SizedBox(height: 20),
              TwoCol(children: [
                SmallField(label: 'Guests', controller: guests, number: true),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Muted('Waiter', size: 12)),
                  AppSelect<String>(
                    value: waiterId,
                    width: double.infinity,
                    items: [('', '— None —'), for (final w in waiters) (str(w['id']), str(w['name']))],
                    onChanged: (v) => setState(() => waiterId = v),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),
              SmallField(label: 'Customer (optional)', controller: custName, hint: 'Walk-in'),
              const SizedBox(height: 20),
              Btn(pending ? 'Opening…' : 'Open & seat', expand: true, onPressed: pending ? null : openTable),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _active() {
    final s = session!;
    final header = 'Table ${table['number']}${has(table['name']) ? ' · ${table['name']}' : ''} · ${s['customerCount']} guests'
        '${has(s['waiterName']) ? ' · ${s['waiterName']}' : ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
        backLink(),
        Muted(header, size: 14),
      ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth + 120 >= 1024;
        final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (cartCount > 0) ...[_cartCard(), const SizedBox(height: 16)],
          if (mergeTargets.isNotEmpty) ...[_mergeCard(), const SizedBox(height: 16)],
          _billCard(s),
        ]);
        if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_menuCard(), const SizedBox(height: 16), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _menuCard()),
          const SizedBox(width: 16),
          SizedBox(width: 360, child: right),
        ]);
      }),
    ]);
  }

  Widget _menuCard() {
    final c = context.c;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(hint: 'Search dishes…', width: 192, onChanged: (v) => setState(() => query = v)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in cats)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => cat = k),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cat == k ? c.accent : null,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cat == k ? c.accent : c.border),
                  ),
                  child: Text(k, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cat == k ? Colors.white : c.fgMuted)),
                ),
              ),
          ]),
        ]),
        const SizedBox(height: 16),
        ColsGrid(
          gap: 8,
          cols: (w) => w + 120 >= 640 ? 3 : 2,
          children: [
            for (final m in filtered)
              _MenuTile(
                name: str(m['name']),
                price: money(m['price']),
                inCart: cart[m['id']] ?? 0,
                onTap: () => add(str(m['id'])),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _cartCard() => AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Caption('New items', bold: true),
          for (final l in cartLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: Text(str(l['name']), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                QtyBtn('−', onTap: () => sub(str(l['menuItemId']))),
                SizedBox(width: 26, child: Text('${l['qty']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
                QtyBtn('+', onTap: () => add(str(l['menuItemId']))),
              ]),
            ),
          const SizedBox(height: 6),
          Btn('Send to kitchen · ${money(cartTotal)}', icon: LucideIcons.chefHat, expand: true, onPressed: pending ? null : sendToKitchen),
        ]),
      );

  Widget _mergeCard() => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Caption('Merge table', bold: true),
          Row(children: [
            Expanded(
              child: AppSelect<String>(
                value: mergeId,
                width: double.infinity,
                items: [('', 'Select a table…'), for (final m in mergeTargets) (str(m['sessionId']), 'Table ${m['number']}')],
                onChanged: (v) => setState(() => mergeId = v),
              ),
            ),
            const SizedBox(width: 8),
            Btn('Merge', kind: BtnKind.ghost, icon: LucideIcons.combine, onPressed: pending || mergeId.isEmpty ? null : doMerge),
          ]),
        ]),
      );

  Widget _billCard(Json s) {
    final c = context.c;
    final lines = asJsonList(s['lines']);
    final payments = asJsonList(s['payments']);
    final paid = toNum(s['paid']);
    final remaining = math.max(0, previewTotal - paid);
    Widget kv(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(fontSize: 14, color: c.fgMuted))),
            Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          ]),
        );
    Widget adj(String label, TextEditingController ctl) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: c.fgMuted))),
            Text(r'$', style: TextStyle(fontSize: 14, color: c.fgMuted)),
            const SizedBox(width: 4),
            SizedBox(width: 96, child: AppInput(controller: ctl, number: true, dense: true, textAlign: TextAlign.right, onChanged: (_) => setState(() {}))),
          ]),
        );
    final methods = [for (final m in paymentMethods) (m, m)];
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Caption('Bill', bold: true, bottom: 0)),
          LinkBtn('KOT', icon: LucideIcons.printer, onTap: () => printDoc('KOT', kotHtml(lines))),
        ]),
        const SizedBox(height: 12),
        if (lines.isEmpty)
          Muted('No items yet — add from the menu.', size: 14)
        else
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                QtyBtn('−', size: 20, hover: c.danger, onTap: pending ? null : () => line(str(l['menuItemId']), -1)),
                SizedBox(width: 22, child: Text('${l['qty']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                QtyBtn('+', size: 20, onTap: pending ? null : () => line(str(l['menuItemId']), 1)),
                const SizedBox(width: 6),
                Expanded(child: Text(str(l['name']), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                Muted(money(toNum(l['qty']) * toNum(l['price'])), size: 14),
              ]),
            ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            kv('Subtotal', money(s['subtotal'])),
            adj('Discount', discount),
            adj('Tax', tax),
            adj('Service', service),
            adj('Tip', tip),
            Align(alignment: Alignment.centerLeft, child: LinkBtn('Save adjustments', color: c.accent, onTap: pending ? null : saveBilling)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Row(children: [
                const Expanded(child: Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                Text(money(previewTotal), style: display(context, size: 20)),
              ]),
            ),
            if (paid > 0) ...[
              const SizedBox(height: 8),
              kv('Paid', money(paid), color: c.success),
              kv('Remaining', money(remaining)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Boxed(
          padding: const EdgeInsets.all(12),
          radius: 8,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Caption('Split / partial payment', bold: true),
            if (payments.isNotEmpty) ...[
              for (final p in payments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [Expanded(child: Muted(str(p['method']), size: 12)), Muted(money(p['amount']), size: 12)]),
                ),
              const SizedBox(height: 4),
            ],
            Row(children: [
              SizedBox(width: 96, child: AppInput(controller: payAmount, hint: 'Amount', number: true, dense: true)),
              const SizedBox(width: 8),
              Expanded(child: AppSelect<String>(value: payMethod2, width: double.infinity, items: methods, onChanged: (v) => setState(() => payMethod2 = v))),
              const SizedBox(width: 8),
              Btn('Add', kind: BtnKind.ghost, small: true, onPressed: pending ? null : doAddPayment),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Btn('Print invoice', kind: BtnKind.ghost, icon: LucideIcons.receipt, expand: true, onPressed: printInvoice),
        const SizedBox(height: 8),
        Row(children: [
          AppSelect<String>(value: payMethod, items: methods, onChanged: (v) => setState(() => payMethod = v)),
          const SizedBox(width: 8),
          Expanded(
            child: Btn('Close & Pay${paid > 0 ? ' · ${money(remaining)}' : ''}', expand: true, onPressed: pending ? null : closeAndPay),
          ),
        ]),
      ]),
    );
  }
}

class _MenuTile extends StatefulWidget {
  const _MenuTile({required this.name, required this.price, required this.inCart, required this.onTap});
  final String name, price;
  final int inCart;
  final VoidCallback onTap;
  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: hover ? c.accent.withValues(alpha: .4) : c.border), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(widget.price, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.accent)),
            if (widget.inCart > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Muted('In cart: ${widget.inCart}', size: 12)),
          ]),
        ),
      ),
    );
  }
}
