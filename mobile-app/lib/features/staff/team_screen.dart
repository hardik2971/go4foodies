import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'staff_providers.dart';

const _duty = ['ON_DUTY', 'ON_BREAK', 'ABSENT', 'OFF'];

/// Staff directory (admin /staff): duty status, active toggle, CRUD.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});
  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  String _q = '';
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.goldBrand,
        foregroundColor: AppColors.ink,
        onPressed: () => _form(context, roles: _roles()),
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: AsyncBody<Json>(
        value: ref.watch(staffListProvider),
        onRefresh: () async => ref.refresh(staffListProvider.future),
        builder: (data) {
          final all = ((data['employees'] as List?) ?? const []).cast<Json>();
          final counts = {for (final d in _duty) d: all.where((e) => e['status'] == d).length};
          final shown = all
              .where((e) => (_filter == 'ALL' || e['status'] == _filter) && '${e['name']} ${e['role']}'.toLowerCase().contains(_q.toLowerCase()))
              .toList();
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
            Row(children: [
              Expanded(child: KpiTile(label: 'On duty', value: '${counts['ON_DUTY']}', icon: Icons.badge_outlined, highlight: true)),
              const SizedBox(width: 10),
              Expanded(child: KpiTile(label: 'Team size', value: '${all.length}', icon: Icons.groups_2_outlined)),
            ]),
            const SizedBox(height: 12),
            TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Search staff', prefixIcon: Icon(Icons.search_rounded))),
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(top: 8), children: [
                for (final f in ['ALL', ..._duty])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f == 'ALL' ? 'All ${all.length}' : '${humanize(f)} ${counts[f]}'),
                      selected: _filter == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 4),
            for (final e in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _form(context, roles: ((data['roles'] as List?) ?? const []).cast<String>(), employee: e),
                  child: Row(children: [
                    Opacity(opacity: e['active'] == true ? 1 : 0.45, child: Avatar(_initials(e['name'] as String), size: 42)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${e['role']}${e['active'] == true ? '' : ' · inactive'}', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                      ]),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Duty status',
                      onSelected: (s) => guard(context, () async {
                        await ref.read(apiProvider).patch('$staffApi/staff/${e['id']}/status', {'status': s});
                        ref.invalidate(staffListProvider);
                      }),
                      itemBuilder: (_) => [for (final d in _duty) PopupMenuItem(value: d, child: Text(humanize(d)))],
                      child: StatusChip(e['status'] as String),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  List<String> _roles() => ((ref.read(staffListProvider).valueOrNull?['roles'] as List?) ?? const ['Waiter']).cast<String>();

  String _initials(String n) => n.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();

  Future<void> _form(BuildContext context, {required List<String> roles, Json? employee}) async {
    final e = employee;
    final name = TextEditingController(text: e?['name'] as String? ?? '');
    final email = TextEditingController(text: e?['email'] as String? ?? '');
    final phone = TextEditingController(text: e?['phone'] as String? ?? '');
    final password = TextEditingController();
    var role = roles.contains(e?['role']) ? e!['role'] as String : (roles.contains('Waiter') ? 'Waiter' : roles.first);
    var active = e?['active'] as bool? ?? true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(e == null ? 'Add staff member' : 'Edit staff member', style: display(ctx, size: 22)),
              const SizedBox(height: 14),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (Restaurant app login)')),
              const SizedBox(height: 10),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: e == null ? 'App password (min 6, optional)' : 'New app password (leave blank to keep)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => set(() => role = v ?? role),
              ),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (v) => set(() => active = v)),
              const SizedBox(height: 8),
              Row(children: [
                if (e != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: ctx.c.danger),
                    onPressed: () async {
                      if (!await confirm(ctx, title: 'Remove ${e['name']}?', confirmLabel: 'Remove', destructive: true) || !ctx.mounted) return;
                      final ok = await guard(ctx, () async {
                        await ref.read(apiProvider).delete('$staffApi/staff/${e['id']}');
                        ref.invalidate(staffListProvider);
                      });
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final body = {
                        'name': name.text.trim(),
                        'email': email.text.trim(),
                        'phone': phone.text.trim(),
                        'password': password.text,
                        'role': role,
                        'active': active,
                      };
                      final ok = await guard(ctx, () async {
                        final api = ref.read(apiProvider);
                        e == null ? await api.post('$staffApi/staff', body) : await api.put('$staffApi/staff/${e['id']}', body);
                        ref.invalidate(staffListProvider);
                      }, success: 'Saved');
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Customer CRM (admin /customers).
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.goldBrand,
        foregroundColor: AppColors.ink,
        onPressed: () => _form(context),
        child: const Icon(Icons.person_add_alt_rounded),
      ),
      body: AsyncBody<List<Json>>(
        value: ref.watch(customersProvider),
        onRefresh: () async => ref.refresh(customersProvider.future),
        builder: (all) {
          final shown = all.where((c) => '${c['name']} ${c['email']} ${c['phone'] ?? ''}'.toLowerCase().contains(_q.toLowerCase())).toList();
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
            TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Search name, email, phone', prefixIcon: Icon(Icons.search_rounded))),
            const SizedBox(height: 10),
            Text('${all.length} customers', style: TextStyle(color: context.c.muted)),
            const SizedBox(height: 8),
            for (final cst in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _detail(context, cst),
                  child: Row(children: [
                    Avatar((cst['name'] as String).isEmpty ? '?' : (cst['name'] as String)[0].toUpperCase(), size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cst['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(cst['email'] as String, style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(asNum(cst['totalSpend'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${(cst['orders'] as List?)?.length ?? 0} orders', style: TextStyle(color: context.c.muted, fontSize: 12)),
                    ]),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  void _detail(BuildContext context, Json cst) {
    final orders = ((cst['orders'] as List?) ?? const []).cast<Json>();
    final res = ((cst['reservations'] as List?) ?? const []).cast<Json>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Row(children: [
            Expanded(child: Text(cst['name'] as String, style: display(ctx, size: 24))),
            StatusChip(cst['status'] as String),
          ]),
          const SizedBox(height: 10),
          KeyValue('Email', cst['email'] as String),
          KeyValue('Phone', (cst['phone'] as String?) ?? '—'),
          KeyValue('Lifetime spend', money(asNum(cst['totalSpend'])), bold: true),
          KeyValue('Last activity', fmtDate(cst['lastActivity'], 'd MMM y')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () {
              Navigator.pop(ctx);
              _form(context, customer: cst);
            }, icon: const Icon(Icons.edit_outlined), label: const Text('Edit'))),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: ctx.c.danger),
                onPressed: () async {
                  if (!await confirm(ctx, title: 'Delete ${cst['name']}?', confirmLabel: 'Delete', destructive: true) || !ctx.mounted) return;
                  final ok = await guard(ctx, () async {
                    await ref.read(apiProvider).delete('$staffApi/customers/${cst['id']}');
                    ref.invalidate(customersProvider);
                  }, success: 'Customer deleted');
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ),
          ]),
          const SectionTitle('Orders', padding: EdgeInsets.fromLTRB(0, 20, 0, 8)),
          if (orders.isEmpty) Text('No orders', style: TextStyle(color: ctx.c.muted)),
          for (final o in orders)
            ListTile(contentPadding: EdgeInsets.zero, title: Text(o['number'] as String), subtitle: Text(fmtDate(o['date'])), trailing: Text(money(asNum(o['total'])))),
          const SectionTitle('Reservations', padding: EdgeInsets.fromLTRB(0, 12, 0, 8)),
          if (res.isEmpty) Text('No reservations', style: TextStyle(color: ctx.c.muted)),
          for (final r in res)
            ListTile(contentPadding: EdgeInsets.zero, title: Text(r['reference'] as String), subtitle: Text(fmtDate(r['date'])), trailing: StatusChip(r['status'] as String)),
        ]),
      ),
    );
  }

  Future<void> _form(BuildContext context, {Json? customer}) async {
    final c = customer;
    final name = TextEditingController(text: c?['name'] as String? ?? '');
    final email = TextEditingController(text: c?['email'] as String? ?? '');
    final phone = TextEditingController(text: c?['phone'] as String? ?? '');
    final address = TextEditingController(text: c?['address'] as String? ?? '');
    var active = (c?['status'] ?? 'ACTIVE') == 'ACTIVE';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c == null ? 'New customer' : 'Edit customer', style: display(ctx, size: 22)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 10),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (v) => set(() => active = v)),
            FilledButton(
              onPressed: () async {
                final body = {'name': name.text.trim(), 'email': email.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim(), 'status': active ? 'ACTIVE' : 'INACTIVE'};
                final ok = await guard(ctx, () async {
                  final api = ref.read(apiProvider);
                  c == null ? await api.post('$staffApi/customers', body) : await api.put('$staffApi/customers/${c['id']}', body);
                  ref.invalidate(customersProvider);
                }, success: 'Saved');
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      ),
    );
  }
}
