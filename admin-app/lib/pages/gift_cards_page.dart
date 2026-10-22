import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/biz_widgets.dart';
import '../widgets/ui.dart';

/// gift-cards/index.blade.php — giftCardsManager().
class GiftCardsPage extends StatelessWidget {
  const GiftCardsPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: () async {
          final d = await Api.get('/gift-cards');
          return [for (final c in (d['cards'] as List? ?? const [])) Map<String, dynamic>.from(c)];
        },
        builder: (context, data, _) => _GiftCardsView(initial: data),
      );
}

const _kindLabels = {'GIFT_CARD': 'Gift Card', 'COUPON': 'Coupon'};
const _statuses = ['PENDING_PAYMENT', 'PAID', 'ACTIVE', 'REDEEMED', 'EXPIRED', 'CANCELLED'];
const _statusLabels = {
  'PENDING_PAYMENT': 'Pending Payment',
  'PAID': 'Paid',
  'ACTIVE': 'Active',
  'REDEEMED': 'Redeemed',
  'EXPIRED': 'Expired',
  'CANCELLED': 'Cancelled',
};
const _statusTones = {
  'PENDING_PAYMENT': Tone.warn,
  'PAID': Tone.info,
  'ACTIVE': Tone.success,
  'REDEEMED': Tone.accent,
  'EXPIRED': Tone.muted,
  'CANCELLED': Tone.danger,
};
const _paymentLabels = {'PENDING': 'Pending', 'PAID': 'Paid', 'FAILED': 'Failed'};
// Quick status transitions available from the detail view.
const _quickActions = [
  (status: 'ACTIVE', label: 'Activate', danger: false),
  (status: 'REDEEMED', label: 'Mark Redeemed', danger: false),
  (status: 'EXPIRED', label: 'Expire', danger: false),
  (status: 'CANCELLED', label: 'Cancel', danger: true),
];

String _gatewayLabel(dynamic p) => p == 'stripe' ? 'Stripe' : p == 'paypal' ? 'PayPal' : 'Razorpay';
String _s(dynamic v) => v == null ? '' : '$v';

Widget _statusBadge(String status) => ToneBadge(_statusLabels[status] ?? '', tone: _statusTones[status] ?? Tone.muted, dot: true);

class _GiftCardsView extends StatefulWidget {
  const _GiftCardsView({required this.initial});
  final List<Map<String, dynamic>> initial;
  @override
  State<_GiftCardsView> createState() => _GiftCardsViewState();
}

class _GiftCardsViewState extends State<_GiftCardsView> {
  late List<Map<String, dynamic>> cards = widget.initial;
  String status = 'ALL', kind = 'ALL', query = '';

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    return cards.where((c) {
      return (status == 'ALL' || c['status'] == status) &&
          (kind == 'ALL' || c['kind'] == kind) &&
          (q.isEmpty ||
              _s(c['code']).toLowerCase().contains(q) ||
              _s(c['customerName']).toLowerCase().contains(q) ||
              _s(c['customerEmail']).toLowerCase().contains(q));
    }).toList();
  }

  void exportCsv() {
    final header = ['Code', 'Type', 'Customer', 'Email', 'Amount', 'Payment', 'Status', 'Expiry', 'Created'];
    final data = [
      for (final r in filtered)
        [
          r['code'],
          _kindLabels[r['kind']],
          r['customerName'],
          r['customerEmail'],
          numOf(r['amount']).toStringAsFixed(2),
          _paymentLabels[r['paymentStatus']],
          _statusLabels[r['status']],
          r['expiryDate'] ?? '',
          _s(r['createdAt']).length >= 10 ? _s(r['createdAt']).substring(0, 10) : _s(r['createdAt']),
        ],
    ];
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    downloadCsv('gift-cards-$today.csv', [header, ...data]);
  }

  Future<void> changeStatus(Map<String, dynamic> card, String next, [VoidCallback? refresh]) async {
    final prev = card['status'];
    setState(() => card['status'] = next);
    refresh?.call();
    final ok = await guard(() => Api.patch('/gift-cards/${card['id']}/status', {'status': next}));
    if (!ok) {
      card['status'] = prev;
      if (mounted) setState(() {});
      refresh?.call();
    }
  }

  Future<void> remove(Map<String, dynamic> c) async {
    if (!await confirmDialog(context, 'Delete ${c['code']}?')) return;
    final before = cards;
    setState(() => cards = cards.where((x) => x['id'] != c['id']).toList());
    final ok = await guard(() => Api.delete('/gift-cards/${c['id']}'));
    if (!ok && mounted) setState(() => cards = before);
  }

  void openView(Map<String, dynamic> c) {
    showAppModal(context, title: _s(c['code']), builder: (_) => _GiftCardDetail(card: c, onChangeStatus: changeStatus));
  }

  void openEdit(Map<String, dynamic> c) {
    showAppModal(context, title: 'Edit ${c['code']}', builder: (_) => _GiftCardForm(card: c, onSaved: () => setState(() {})));
  }

  @override
  Widget build(BuildContext context) {
    final rows = filtered;
    final paidValue = cards.where((c) => c['paymentStatus'] == 'PAID').fold<num>(0, (s, c) => s + numOf(c['amount']));
    return Gap(children: [
      StatsGrid(children: [
        StatTile(icon: LucideIcons.gift, label: 'Total Purchases', value: '${cards.length}'),
        StatTile(icon: LucideIcons.dollarSign, label: 'Total Value', value: money(paidValue)),
        StatTile(icon: LucideIcons.circleCheck, label: 'Active', value: '${cards.where((c) => c['status'] == 'ACTIVE').length}'),
        StatTile(icon: LucideIcons.clock, label: 'Redeemed', value: '${cards.where((c) => c['status'] == 'REDEEMED').length}'),
      ]),
      BizToolbar(
        left: FilterPills<String>(
          options: const ['ALL', ..._statuses],
          value: status,
          label: (s) => s == 'ALL' ? 'All' : _statusLabels[s]!,
          onChanged: (s) => setState(() => status = s),
        ),
        right: [
          AppSelect<String>(
            value: kind,
            items: const [('ALL', 'All types'), ('GIFT_CARD', 'Gift Cards'), ('COUPON', 'Coupons')],
            onChanged: (v) => setState(() => kind = v),
          ),
          SearchField(hint: 'Search code, name, email…', width: 208, onChanged: (v) => setState(() => query = v)),
          Btn('Export', icon: LucideIcons.download, kind: BtnKind.ghost, onPressed: exportCsv),
        ],
      ),
      BizTable(
        empty: 'No purchases match your filters.',
        minWidth: 980,
        columns: const [
          DataCol('Code', flex: 2),
          DataCol('Customer', flex: 3),
          DataCol('Type', flex: 2),
          DataCol('Amount', flex: 2),
          DataCol('Payment', flex: 2),
          DataCol('Status', flex: 2),
          DataCol('Created', flex: 2),
          DataCol('Actions', flex: 2, align: TextAlign.right),
        ],
        rows: [
          for (final c in rows)
            // Spent / terminal coupons — dim the row to read as inactive.
            BizRow(opacity: const ['REDEEMED', 'EXPIRED', 'CANCELLED'].contains(c['status']) ? .5 : 1, [
              Text(_s(c['code']), style: mono(color: context.c.fg), overflow: TextOverflow.ellipsis),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_s(c['customerName']), style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                Text(_s(c['customerEmail']).isEmpty ? '—' : _s(c['customerEmail']),
                    style: TextStyle(fontSize: 12, color: context.c.fgMuted), overflow: TextOverflow.ellipsis),
              ]),
              CellText(_kindLabels[c['kind']] ?? ''),
              CellText(money(numOf(c['amount'])), muted: false, weight: FontWeight.w500),
              CellText(_paymentLabels[c['paymentStatus']] ?? ''),
              _statusBadge(_s(c['status'])),
              CellText(fmtDate(c['createdAt'], 'MMM d, yyyy')),
              RowActions([
                RowAction(LucideIcons.eye, tooltip: 'View', onTap: () => openView(c)),
                RowAction(LucideIcons.pencil, tooltip: 'Edit', onTap: () => openEdit(c)),
                RowAction(LucideIcons.trash2, tooltip: 'Delete', danger: true, onTap: () => remove(c)),
              ]),
            ]),
        ],
      ),
    ]);
  }
}

class _GiftCardDetail extends StatefulWidget {
  const _GiftCardDetail({required this.card, required this.onChangeStatus});
  final Map<String, dynamic> card;
  final Future<void> Function(Map<String, dynamic> card, String next, [VoidCallback? refresh]) onChangeStatus;
  @override
  State<_GiftCardDetail> createState() => _GiftCardDetailState();
}

class _GiftCardDetailState extends State<_GiftCardDetail> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = widget.card;
    final rows = <(String, String)>[
      ('Customer', _s(v['customerName'])),
      ('Email', _s(v['customerEmail']).isEmpty ? '—' : _s(v['customerEmail'])),
      ('Payment', _paymentLabels[v['paymentStatus']] ?? ''),
      ('Expiry', v['expiryDate'] == null ? 'No expiry' : _s(v['expiryDate'])),
      ('Created', fmtDate(v['createdAt'], 'MMM d, yyyy')),
      if (_s(v['razorpayPaymentId']).isNotEmpty) ('${_gatewayLabel(v['paymentProvider'])} Payment', _s(v['razorpayPaymentId'])),
    ];
    final message = _s(v['message']);

    Widget tile((String, String) r) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.$1, style: TextStyle(fontSize: 12, color: c.fgMuted)),
            const SizedBox(height: 2),
            Text(r.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
        );

    return Gap(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Pill(_kindLabels[v['kind']] ?? ''),
        _statusBadge(_s(v['status'])),
      ]),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: c.gold.withValues(alpha: .1),
          border: Border.all(color: c.gold.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Caption('Code', letterSpacing: 12 * .2),
          const SizedBox(height: 4),
          Text(_s(v['code']), textAlign: TextAlign.center, style: mono(size: 24, weight: FontWeight.w700, color: c.fg, letterSpacing: 24 * .1)),
          const SizedBox(height: 4),
          Text(money(numOf(v['amount'])), style: display(context, size: 20)),
        ]),
      ),
      LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final r in rows) SizedBox(width: w, child: tile(r))]);
      }),
      if (message.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Message', style: TextStyle(fontSize: 12, color: c.fgMuted)),
            const SizedBox(height: 2),
            Text('“$message”', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
          ]),
        ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Caption('Update status')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in _quickActions.where((a) => a.status != v['status']))
            Btn(a.label, kind: a.danger ? BtnKind.dangerOutline : BtnKind.primary, onPressed: () => widget.onChangeStatus(v, a.status, _refresh)),
        ]),
      ]),
    ]);
  }
}

class _GiftCardForm extends StatefulWidget {
  const _GiftCardForm({required this.card, required this.onSaved});
  final Map<String, dynamic> card;
  final VoidCallback onSaved;
  @override
  State<_GiftCardForm> createState() => _GiftCardFormState();
}

class _GiftCardFormState extends State<_GiftCardForm> {
  late final g = widget.card;
  late final customerName = TextEditingController(text: _s(g['customerName']));
  late final customerEmail = TextEditingController(text: _s(g['customerEmail']));
  late final amount = TextEditingController(text: jsNum(numOf(g['amount'])));
  late final expiryDate = TextEditingController(text: _s(g['expiryDate']));
  late String kind = _s(g['kind']).isEmpty ? 'GIFT_CARD' : _s(g['kind']);
  late String status = _s(g['status']);
  late String paymentStatus = _s(g['paymentStatus']);
  bool saving = false;
  Map<String, String> errors = {};

  @override
  void dispose() {
    for (final c in [customerName, customerEmail, amount, expiryDate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final errs = <String, String>{};
    if (customerName.text.trim().length < 2) errs['customerName'] = 'Name is required';
    if (customerEmail.text.isNotEmpty && !isEmail(customerEmail.text)) errs['customerEmail'] = 'Invalid email';
    final amt = num.tryParse(amount.text.trim());
    if (!(amt != null && amt > 0)) errs['amount'] = 'Amount must be positive';
    setState(() => errors = errs);
    if (errs.isNotEmpty) return;
    final values = {
      'customerName': customerName.text,
      'customerEmail': customerEmail.text,
      'kind': kind,
      'amount': amt,
      'status': status,
      'paymentStatus': paymentStatus,
      'expiryDate': expiryDate.text,
    };
    setState(() => saving = true);
    try {
      await Api.put('/gift-cards/${g['id']}', values);
      g
        ..['customerName'] = values['customerName']
        ..['customerEmail'] = customerEmail.text
        ..['kind'] = kind
        ..['amount'] = amt
        ..['status'] = status
        ..['paymentStatus'] = paymentStatus
        ..['expiryDate'] = expiryDate.text.isEmpty ? null : expiryDate.text;
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      toast(err is ApiError ? err.message : '$err', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Gap(gap: 16, children: [
        Cols([
          BizField(label: 'Customer name', controller: customerName, error: errors['customerName']),
          BizField(label: 'Customer email', controller: customerEmail, error: errors['customerEmail']),
        ]),
        Cols([
          BizSelect<String>(
            label: 'Type',
            value: kind,
            items: const [('GIFT_CARD', 'Gift Card'), ('COUPON', 'Coupon')],
            onChanged: (v) => setState(() => kind = v),
          ),
          BizField(label: r'Amount ($)', controller: amount, number: true, error: errors['amount']),
        ]),
        Cols([
          BizSelect<String>(
            label: 'Status',
            value: status,
            items: [for (final s in _statuses) (s, _statusLabels[s]!)],
            onChanged: (v) => setState(() => status = v),
          ),
          BizSelect<String>(
            label: 'Payment',
            value: paymentStatus,
            items: const [('PENDING', 'Pending'), ('PAID', 'Paid'), ('FAILED', 'Failed')],
            onChanged: (v) => setState(() => paymentStatus = v),
          ),
        ]),
        DateField(label: 'Expiry date', labelHint: '(optional)', controller: expiryDate),
        ModalActions(submitLabel: 'Save changes', saving: saving, onSubmit: submit),
      ]);
}
