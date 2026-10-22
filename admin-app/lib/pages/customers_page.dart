import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/biz_widgets.dart';
import '../widgets/ui.dart';

/// customers/index.blade.php — customersManager().
class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: () async {
          final d = await Api.get('/customers');
          return [for (final c in (d['customers'] as List? ?? const [])) Map<String, dynamic>.from(c)];
        },
        builder: (context, data, _) => _CustomersView(initial: data),
      );
}

List<Map> _list(dynamic v) => [for (final x in (v as List? ?? const [])) Map.from(x)];
int _visits(Map c) => _list(c['orders']).length + _list(c['reservations']).length;
bool _isActive(Map c) => c['status'] == 'ACTIVE';

class _CustomersView extends StatefulWidget {
  const _CustomersView({required this.initial});
  final List<Map<String, dynamic>> initial;
  @override
  State<_CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<_CustomersView> {
  late List<Map<String, dynamic>> customers = widget.initial;
  String query = '', statusFilter = 'ALL';

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    return customers.where((c) {
      return (statusFilter == 'ALL' || c['status'] == statusFilter) &&
          (q.isEmpty ||
              '${c['name'] ?? ''}'.toLowerCase().contains(q) ||
              '${c['email'] ?? ''}'.toLowerCase().contains(q) ||
              '${c['phone'] ?? ''}'.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> remove(Map<String, dynamic> c) async {
    if (!await confirmDialog(context, 'Delete customer "${c['name']}"?')) return;
    final before = customers;
    setState(() => customers = customers.where((x) => x['id'] != c['id']).toList());
    final ok = await guard(() => Api.delete('/customers/${c['id']}'));
    if (!ok && mounted) setState(() => customers = before);
  }

  void openForm([Map<String, dynamic>? editing]) {
    showAppModal(
      context,
      title: editing != null ? 'Edit customer' : 'Add customer',
      builder: (_) => _CustomerForm(
        editing: editing,
        onSaved: (list) => setState(() {
          if (list != null) customers = list;
        }),
      ),
    );
  }

  void openView(Map<String, dynamic> c, int index) {
    showAppModal(context, title: 'Customer', builder: (_) => _CustomerView(customer: c, index: index));
  }

  @override
  Widget build(BuildContext context) {
    final lifetime = customers.fold<num>(0, (s, c) => s + numOf(c['totalSpend']));
    final repeat = customers.where((c) => _visits(c) > 1).length;
    final avg = customers.isEmpty ? 0 : jsRound(lifetime / customers.length);
    final rows = filtered;

    return Gap(children: [
      StatsGrid(children: [
        StatTile(icon: LucideIcons.users, label: 'Total Customers', value: '${customers.length}'),
        StatTile(icon: LucideIcons.dollarSign, label: 'Lifetime Value', value: money(lifetime)),
        StatTile(icon: LucideIcons.trendingUp, label: 'Avg Spend', value: money(avg)),
        StatTile(icon: LucideIcons.repeat, label: 'Repeat Guests', value: '$repeat'),
      ]),
      BizToolbar(
        left: FilterPills<String>(
          options: const ['ALL', 'ACTIVE', 'INACTIVE'],
          value: statusFilter,
          label: (s) => s == 'ALL' ? 'All' : s == 'ACTIVE' ? 'Active' : 'Inactive',
          onChanged: (s) => setState(() => statusFilter = s),
        ),
        right: [
          SearchField(hint: 'Search customers…', width: 208, onChanged: (v) => setState(() => query = v)),
          Btn('Add Customer', icon: LucideIcons.plus, onPressed: () => openForm()),
        ],
      ),
      BizTable(
        empty: 'No customers match your filters.',
        columns: const [
          DataCol('Customer', flex: 3),
          DataCol('Phone', flex: 2),
          DataCol('Address', flex: 3),
          DataCol('Status', flex: 2),
          DataCol('Created', flex: 2),
          DataCol('Actions', flex: 2, align: TextAlign.right),
        ],
        rows: [
          for (final (i, c) in rows.indexed)
            BizRow([
              PersonCell(name: '${c['name'] ?? ''}', sub: '${c['email'] ?? ''}', index: i),
              CellText('${c['phone'] ?? '—'}'),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 256),
                child: CellText('${c['address'] ?? ''}'.isEmpty ? '—' : '${c['address']}'),
              ),
              ToneBadge(_isActive(c) ? 'Active' : 'Inactive', tone: _isActive(c) ? Tone.success : Tone.muted, dot: true),
              CellText(c['createdAt'] != null && c['createdAt'] != '' ? fmtDate(c['createdAt'], 'MMM d, yyyy') : '—'),
              RowActions([
                RowAction(LucideIcons.eye, tooltip: 'View', onTap: () => openView(c, i)),
                RowAction(LucideIcons.pencil, tooltip: 'Edit', onTap: () => openForm(c)),
                RowAction(LucideIcons.trash2, tooltip: 'Delete', danger: true, onTap: () => remove(c)),
              ]),
            ]),
        ],
      ),
    ]);
  }
}

class _CustomerView extends StatelessWidget {
  const _CustomerView({required this.customer, required this.index});
  final Map<String, dynamic> customer;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = customer;
    final orders = _list(v['orders']);
    final reservations = _list(v['reservations']);
    final phone = '${v['phone'] ?? ''}';
    final address = '${v['address'] ?? ''}';

    Widget link(IconData icon, String text, [Uri? uri]) {
      final row = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c.fgMuted),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(fontSize: 14, color: c.fgMuted))),
      ]);
      if (uri == null) return row;
      return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: () => launchUrl(uri), child: row));
    }

    Widget list(String caption, List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Caption(caption)),
          Container(
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              for (var i = 0; i < items.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                  child: items[i],
                ),
            ]),
          ),
        ]);

    Widget line(String a, String b, String d, {bool dMuted = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(b, style: TextStyle(fontSize: 14, color: c.fgMuted)),
          Text(d, style: TextStyle(fontSize: 14, fontWeight: dMuted ? null : FontWeight.w500, color: dMuted ? c.fgMuted : null)),
        ]);

    return Gap(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        InitialsAvatar(name: '${v['name'] ?? ''}', index: index, size: 48, fontSize: 16),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${v['name'] ?? ''}', style: display(context, size: 18)),
              ToneBadge(_isActive(v) ? 'Active' : 'Inactive', tone: _isActive(v) ? Tone.success : Tone.muted, dot: true),
            ]),
            const SizedBox(height: 4),
            link(LucideIcons.mail, '${v['email'] ?? ''}', Uri.parse('mailto:${v['email'] ?? ''}')),
            if (phone.isNotEmpty) ...[const SizedBox(height: 2), link(LucideIcons.phone, phone, Uri.parse('tel:$phone'))],
            if (address.isNotEmpty) ...[const SizedBox(height: 2), link(LucideIcons.mapPin, address)],
          ]),
        ),
      ]),
      Cols(gap: 12, [
        MiniStat(label: 'Lifetime', value: money(numOf(v['totalSpend'])), center: true, valueSize: 18),
        MiniStat(label: 'Orders', value: '${orders.length}', center: true, valueSize: 18),
        MiniStat(label: 'Visits', value: '${_visits(v)}', center: true, valueSize: 18),
      ]),
      if (orders.isNotEmpty)
        list('Order history', [for (final o in orders) line('${o['number']}', fmtDate(o['date'], 'MMM d'), money(numOf(o['total'])))]),
      if (reservations.isNotEmpty)
        list('Reservations', [
          for (final r in reservations) line('${r['reference']}', fmtDate(r['date'], 'MMM d'), r['kind'] == 'TABLE' ? 'Table' : 'Event', dMuted: true),
        ]),
    ]);
  }
}

class _CustomerForm extends StatefulWidget {
  const _CustomerForm({required this.editing, required this.onSaved});
  final Map<String, dynamic>? editing;
  final void Function(List<Map<String, dynamic>>? replaced) onSaved;
  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  late final e = widget.editing;
  late final name = TextEditingController(text: '${e?['name'] ?? ''}');
  late final email = TextEditingController(text: '${e?['email'] ?? ''}');
  late final phone = TextEditingController(text: '${e?['phone'] ?? ''}');
  late final address = TextEditingController(text: '${e?['address'] ?? ''}');
  late String status = '${e?['status'] ?? 'ACTIVE'}';
  bool saving = false;
  Map<String, String> errors = {};

  @override
  void dispose() {
    for (final c in [name, email, phone, address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final errs = <String, String>{};
    if (name.text.trim().length < 2) errs['name'] = 'Name is required';
    if (!isEmail(email.text)) errs['email'] = 'Enter a valid email';
    setState(() => errors = errs);
    if (errs.isNotEmpty) return;
    final values = {'name': name.text, 'email': email.text, 'phone': phone.text, 'address': address.text, 'status': status};
    setState(() => saving = true);
    try {
      if (e != null) {
        await Api.put('/customers/${e!['id']}', values);
        e!.addAll(values);
        e!['phone'] = phone.text.isEmpty ? null : phone.text;
        e!['address'] = address.text.isEmpty ? null : address.text;
        widget.onSaved(null);
      } else {
        final res = await Api.post('/customers', values);
        widget.onSaved([for (final x in (res['customers'] as List? ?? const [])) Map<String, dynamic>.from(x)]);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      toast(err is ApiError ? err.message : '$err', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Gap(gap: 16, children: [
        BizField(label: 'Name', controller: name, hint: 'Jane Doe', error: errors['name']),
        Cols([
          BizField(label: 'Email', controller: email, hint: 'jane@email.com', error: errors['email']),
          BizField(label: 'Phone', controller: phone, hint: '+1 555 000 0000'),
        ]),
        BizField(label: 'Address', controller: address, hint: 'Street, City, State'),
        BizSelect<String>(
          label: 'Status',
          value: status,
          items: const [('ACTIVE', 'Active'), ('INACTIVE', 'Inactive')],
          onChanged: (v) => setState(() => status = v),
        ),
        ModalActions(submitLabel: e != null ? 'Save changes' : 'Add customer', saving: saving, onSubmit: submit),
      ]);
}
