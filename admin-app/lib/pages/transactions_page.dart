import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/ui.dart';

/// Transactions — port of transactions/index.blade.php (GET /transactions; read-only, client filters).
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: () async {
          final res = await Api.get('/transactions') as Map;
          return [for (final t in (res['transactions'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
        },
        builder: (context, txns, _) => _Transactions(transactions: txns),
      );
}

const _gateways = ['Razorpay', 'Stripe', 'PayPal'];
const _sources = ['ALL', 'Order', 'Gift Card', 'Table'];

class _Transactions extends StatefulWidget {
  const _Transactions({required this.transactions});
  final List<Map<String, dynamic>> transactions;
  @override
  State<_Transactions> createState() => _TransactionsState();
}

class _TransactionsState extends State<_Transactions> {
  String source = 'ALL', method = 'ALL', query = '';

  String _s(Map<String, dynamic> t, String k) => '${t[k] ?? ''}';

  List<String> get methods => ({for (final t in widget.transactions) _s(t, 'method')}.toList()..sort());

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    return widget.transactions
        .where((t) =>
            (source == 'ALL' || t['source'] == source) &&
            (method == 'ALL' || _s(t, 'method') == method) &&
            (q.isEmpty || _s(t, 'reference').toLowerCase().contains(q) || _s(t, 'customer').toLowerCase().contains(q) || _s(t, 'paymentId').toLowerCase().contains(q)))
        .toList();
  }

  void _exportCsv(List<Map<String, dynamic>> rows) {
    const header = ['Date', 'Source', 'Reference', 'Customer', 'Method', 'Amount', 'Status', 'PaymentId'];
    String date(String d) => (d.length > 19 ? d.substring(0, 19) : d).replaceFirst('T', ' ');
    final data = [
      for (final t in rows)
        [date(_s(t, 'date')), _s(t, 'source'), _s(t, 'reference'), _s(t, 'customer'), _s(t, 'method'), jsNum(t['amount'] ?? 0), _s(t, 'status'), _s(t, 'paymentId')],
    ];
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    downloadCsv('transactions-$today.csv', [header, ...data]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lg = MediaQuery.sizeOf(context).width >= 1024;
    final f = filtered;
    final gateway = f.where((t) => _gateways.contains(t['method'])).toList();
    final total = f.fold<double>(0, (s, t) => s + numOf(t['amount']));
    final gatewayTotal = gateway.fold<double>(0, (s, t) => s + numOf(t['amount']));
    final sourceStyle = <String, (Color, Color)>{
      'Order': (c.accentSoft, c.accent),
      'Gift Card': (c.gold.withValues(alpha: .15), c.fg), // text-gold-deep is an undefined token → default text colour
      'Table': (c.infoSoft, c.info),
    };
    const gatewayBlue = Color(0xFF3395FF);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, box) {
        final cols = lg ? 4 : 2;
        final cw = (box.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final t in [
            StatTile(icon: LucideIcons.receipt, label: 'Transactions', value: '${f.length}'),
            StatTile(icon: LucideIcons.dollarSign, label: 'Total Amount', value: money(total)),
            StatTile(icon: LucideIcons.creditCard, label: 'Gateway Payments', value: '${gateway.length}'),
            StatTile(icon: LucideIcons.dollarSign, label: 'Gateway Amount', value: money(gatewayTotal)),
          ])
            SizedBox(width: cw, child: t),
        ]);
      }),
      const SizedBox(height: 20),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        FilterPills<String>(options: _sources, value: source, label: (s) => s == 'ALL' ? 'All' : s, onChanged: (s) => setState(() => source = s)),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
          AppSelect<String>(
            value: method,
            items: [('ALL', 'All methods'), for (final m in methods) (m, m)],
            onChanged: (v) => setState(() => method = v),
          ),
          SearchField(hint: 'Search ref, customer, payment id…', width: 224, onChanged: (v) => setState(() => query = v)),
          Btn('Export', icon: LucideIcons.download, kind: BtnKind.ghost, onPressed: () => _exportCsv(f)),
        ]),
      ]),
      const SizedBox(height: 20),
      DataTableCard(
        minWidth: 820,
        columns: const [DataCol('Source'), DataCol('Reference', flex: 2), DataCol('Customer', flex: 2), DataCol('Method'), DataCol('Amount'), DataCol('Date')],
        empty: 'No transactions match your filters.',
        rows: [
          for (final t in f)
            () {
              final src = _s(t, 'source');
              final st = sourceStyle[src];
              final pid = _s(t, 'paymentId');
              final m = _s(t, 'method');
              return <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: st?.$1, borderRadius: BorderRadius.circular(6)),
                  child: Text(src, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: st?.$2 ?? c.fg)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(_s(t, 'reference'), style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  if (pid.isNotEmpty) Text(pid, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: c.fgMuted), overflow: TextOverflow.ellipsis),
                ]),
                Muted(_s(t, 'customer'), size: 14),
                _gateways.contains(m) ? Pill(m, fg: gatewayBlue, bg: gatewayBlue.withValues(alpha: .15)) : Muted(m, size: 14),
                Text(money(numOf(t['amount'])), style: const TextStyle(fontWeight: FontWeight.w500)),
                Muted(fmtDate(t['date'], 'MMM d, h:mm a'), size: 14),
              ];
            }(),
        ],
      ),
    ]);
  }
}
