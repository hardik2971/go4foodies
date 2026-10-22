import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/biz_widgets.dart';
import '../widgets/ui.dart';

/// staff/index.blade.php — staffManager().
class StaffPage extends StatelessWidget {
  const StaffPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.get('/staff')),
        builder: (context, data, _) => _StaffView(
          employees: [for (final e in (data['employees'] as List? ?? const [])) Map<String, dynamic>.from(e)],
          roles: List<String>.from(data['roles'] ?? const ['Super Admin', 'Manager', 'Cashier', 'Kitchen Staff', 'Waiter']),
        ),
      );
}

const _pageSize = 12;
const _duties = ['ON_DUTY', 'ON_BREAK', 'ABSENT', 'OFF'];
const _dutyLabels = {'ON_DUTY': 'On Duty', 'ON_BREAK': 'On Break', 'ABSENT': 'Absent', 'OFF': 'Off Shift'};
const _dutyTones = {'ON_DUTY': Tone.success, 'ON_BREAK': Tone.warn, 'ABSENT': Tone.danger, 'OFF': Tone.muted};

class _StaffView extends StatefulWidget {
  const _StaffView({required this.employees, required this.roles});
  final List<Map<String, dynamic>> employees;
  final List<String> roles;
  @override
  State<_StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<_StaffView> {
  late List<Map<String, dynamic>> employees = widget.employees;
  List<String> get roles => widget.roles;
  String status = 'ALL', role = 'ALL', activeFilter = 'ALL', query = '';
  int page = 0;

  bool _active(Map e) => e['active'] == true;

  List<String> get roleOptions {
    final out = <String>[];
    for (final r in [...roles, ...employees.map((e) => '${e['role'] ?? ''}')]) {
      if (!out.contains(r)) out.add(r);
    }
    return out;
  }

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    return employees.where((e) {
      return (status == 'ALL' || e['status'] == status) &&
          (role == 'ALL' || e['role'] == role) &&
          (activeFilter == 'ALL' || (activeFilter == 'ACTIVE' ? _active(e) : !_active(e))) &&
          (q.isEmpty || '${e['name'] ?? ''}'.toLowerCase().contains(q) || '${e['email'] ?? ''}'.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> setDuty(Map<String, dynamic> e, String next) async {
    final prev = e['status'];
    setState(() => e['status'] = next);
    final ok = await guard(() => Api.patch('/staff/${e['id']}/status', {'status': next}));
    if (!ok && mounted) setState(() => e['status'] = prev);
  }

  Future<void> toggleActive(Map<String, dynamic> e) async {
    final next = !_active(e);
    setState(() => e['active'] = next);
    final ok = await guard(() => Api.patch('/staff/${e['id']}/active', {'active': next}));
    if (!ok && mounted) setState(() => e['active'] = !next);
  }

  Future<void> remove(Map<String, dynamic> e) async {
    if (!await confirmDialog(context, 'Delete staff member "${e['name']}"?')) return;
    final before = employees;
    setState(() => employees = employees.where((x) => x['id'] != e['id']).toList());
    final ok = await guard(() => Api.delete('/staff/${e['id']}'));
    if (!ok && mounted) setState(() => employees = before);
  }

  void openForm([Map<String, dynamic>? editing]) {
    showAppModal(
      context,
      title: editing != null ? 'Edit staff' : 'Add staff',
      builder: (_) => _StaffForm(
        editing: editing,
        roles: roles,
        onSaved: (list) => setState(() {
          if (list != null) employees = list;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = filtered;
    final pageCount = math.max(1, (rows.length / _pageSize).ceil());
    final safePage = math.min(page, pageCount - 1);
    final pageRows = rows.skip(safePage * _pageSize).take(_pageSize).toList();

    return Gap(children: [
      StatsGrid(children: [
        StatTile(icon: LucideIcons.users, label: 'Total Staff', value: '${employees.length}'),
        StatTile(icon: LucideIcons.userCheck, label: 'Active', value: '${employees.where(_active).length}'),
        StatTile(icon: LucideIcons.coffee, label: 'On Duty', value: '${employees.where((e) => e['status'] == 'ON_DUTY').length}'),
        StatTile(icon: LucideIcons.userX, label: 'Inactive', value: '${employees.where((e) => !_active(e)).length}'),
      ]),
      BizToolbar(
        left: FilterPills<String>(
          options: const ['ALL', ..._duties],
          value: status,
          label: (s) => s == 'ALL' ? 'All duty' : _dutyLabels[s]!,
          onChanged: (s) => setState(() {
            status = s;
            page = 0;
          }),
        ),
        right: [
          AppSelect<String>(
            value: activeFilter,
            items: const [('ALL', 'All accounts'), ('ACTIVE', 'Active'), ('INACTIVE', 'Inactive')],
            onChanged: (v) => setState(() {
              activeFilter = v;
              page = 0;
            }),
          ),
          AppSelect<String>(
            value: role,
            items: [('ALL', 'All roles'), for (final r in roleOptions) (r, r)],
            onChanged: (v) => setState(() {
              role = v;
              page = 0;
            }),
          ),
          SearchField(
            hint: 'Search staff…',
            width: 176,
            onChanged: (v) => setState(() {
              query = v;
              page = 0;
            }),
          ),
          Btn('Add Staff', icon: LucideIcons.plus, onPressed: () => openForm()),
        ],
      ),
      BizTable(
        empty: 'No staff match your filters.',
        columns: const [
          DataCol('Staff', flex: 3),
          DataCol('Phone', flex: 2),
          DataCol('Role', flex: 2),
          DataCol('Status', flex: 2),
          DataCol('Duty', flex: 2),
          DataCol('Actions', flex: 2, align: TextAlign.right),
        ],
        rows: [
          for (final (i, e) in pageRows.indexed)
            BizRow([
              PersonCell(name: '${e['name'] ?? ''}', sub: '${e['email'] ?? ''}', index: i),
              CellText('${e['phone'] ?? '—'}'),
              CellText('${e['role'] ?? ''}'),
              _ActiveToggle(active: _active(e), onTap: () => toggleActive(e)),
              _DutySelect(value: '${e['status']}', onChanged: (v) => setDuty(e, v)),
              RowActions([
                RowAction(LucideIcons.pencil, tooltip: 'Edit', onTap: () => openForm(e)),
                RowAction(LucideIcons.trash2, tooltip: 'Delete', danger: true, onTap: () => remove(e)),
              ]),
            ]),
        ],
      ),
      Row(children: [
        Expanded(child: Text('${rows.length} staff · page ${safePage + 1} of $pageCount', style: TextStyle(fontSize: 14, color: c.fgMuted))),
        SquareBtn(LucideIcons.chevronLeft, tooltip: 'Previous page', onTap: safePage == 0 ? null : () => setState(() => page = math.max(0, safePage - 1))),
        const SizedBox(width: 8),
        SquareBtn(LucideIcons.chevronRight,
            tooltip: 'Next page', onTap: safePage >= pageCount - 1 ? null : () => setState(() => page = math.min(pageCount - 1, safePage + 1))),
      ]),
    ]);
  }
}

class _ActiveToggle extends StatelessWidget {
  const _ActiveToggle({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: active ? 'Click to deactivate' : 'Click to activate',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: ToneBadge(active ? 'Active' : 'Inactive', tone: active ? Tone.success : Tone.muted, dot: true)),
        ),
      );
}

/// Inline duty select coloured by status.
class _DutySelect extends StatelessWidget {
  const _DutySelect({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = toneColors(context, _dutyTones[value] ?? Tone.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: t.bg, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _duties.contains(value) ? value : null,
          isDense: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          borderRadius: BorderRadius.circular(8),
          dropdownColor: c.surface,
          icon: Icon(LucideIcons.chevronDown, size: 14, color: t.fg),
          style: TextStyle(fontSize: 12, color: t.fg),
          selectedItemBuilder: (_) => [for (final s in _duties) Text(_dutyLabels[s]!, style: TextStyle(fontSize: 12, color: t.fg))],
          items: [for (final s in _duties) DropdownMenuItem(value: s, child: Text(_dutyLabels[s]!, style: TextStyle(fontSize: 12, color: c.fg)))],
          onChanged: (v) {
            if (v != null && v != value) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _StaffForm extends StatefulWidget {
  const _StaffForm({required this.editing, required this.roles, required this.onSaved});
  final Map<String, dynamic>? editing;
  final List<String> roles;
  final void Function(List<Map<String, dynamic>>? replaced) onSaved;
  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  late final e = widget.editing;
  late final name = TextEditingController(text: '${e?['name'] ?? ''}');
  late final email = TextEditingController(text: '${e?['email'] ?? ''}');
  late final phone = TextEditingController(text: '${e?['phone'] ?? ''}');
  final password = TextEditingController();
  late String role = e == null ? 'Waiter' : (widget.roles.contains(e!['role']) ? '${e!['role']}' : 'Waiter');
  late bool active = e == null ? true : e!['active'] == true;
  bool saving = false;
  Map<String, String> errors = {};

  @override
  void dispose() {
    for (final c in [name, email, phone, password]) {
      c.dispose();
    }
    super.dispose();
  }

  bool validate() {
    final errs = <String, String>{};
    if (name.text.trim().length < 2) errs['name'] = 'Name is required';
    if (!isEmail(email.text)) errs['email'] = 'Enter a valid email';
    if (password.text.isNotEmpty && password.text.length < 6) errs['password'] = 'Min 6 characters';
    setState(() => errors = errs);
    return errs.isEmpty;
  }

  Future<void> submit() async {
    if (!validate()) return;
    final values = {'name': name.text, 'email': email.text, 'phone': phone.text, 'password': password.text, 'role': role, 'active': active};
    setState(() => saving = true);
    try {
      if (e != null) {
        await Api.put('/staff/${e!['id']}', values);
        e!
          ..['name'] = values['name']
          ..['email'] = values['email']
          ..['phone'] = phone.text.isEmpty ? null : phone.text
          ..['role'] = role
          ..['active'] = active;
        widget.onSaved(null);
      } else {
        final res = await Api.post('/staff', values);
        widget.onSaved([for (final x in (res['employees'] as List? ?? const [])) Map<String, dynamic>.from(x)]);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      toast(err is ApiError ? err.message : '$err', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = e != null;
    return Gap(gap: 16, children: [
      BizField(label: 'Name', controller: name, hint: 'Jane Doe', error: errors['name']),
      Cols([
        BizField(label: 'Email', controller: email, hint: 'jane@email.com', error: errors['email']),
        BizField(label: 'Phone', controller: phone, hint: '+1 555 000 0000'),
      ]),
      Cols([
        BizSelect<String>(label: 'Role', value: role, items: [for (final r in widget.roles) (r, r)], onChanged: (v) => setState(() => role = v)),
        BizField(
          label: 'Password',
          labelHint: editing ? '(leave blank to keep)' : null,
          controller: password,
          obscure: true,
          hint: editing ? '••••••••' : 'Min 6 characters',
          error: errors['password'],
          autofillHints: const [AutofillHints.newPassword],
        ),
      ]),
      CheckRow(value: active, onChanged: (v) => setState(() => active = v), label: 'Active (can be deactivated to disable the account)'),
      ModalActions(submitLabel: editing ? 'Save changes' : 'Add staff', saving: saving, onSubmit: submit),
    ]);
  }
}
