import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/biz_widgets.dart';
import '../widgets/ui.dart';

/// settings/index.blade.php — Restaurant Profile, Change Password, Team, Roles & Permissions.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.get('/settings')),
        builder: (context, data, _) {
          final profile = Map<String, dynamic>.from(data['profile'] ?? const {});
          final team = [for (final m in (data['team'] as List? ?? const [])) Map<String, dynamic>.from(m)];
          final account = Map<String, dynamic>.from(data['account'] ?? const {});
          final cards = [
            _ProfileCard(profile: profile),
            const _PasswordCard(),
            _TeamCard(team: team, account: account),
            const _RolesCard(),
          ];
          // grid grid-cols-1 gap-5 lg:grid-cols-2 (rows stretch to the tallest card).
          if (MediaQuery.of(context).size.width < 1024) return Gap(children: cards);
          Widget row(Widget a, Widget b) => IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: a), const SizedBox(width: 20), Expanded(child: b)]),
              );
          return Gap(children: [row(cards[0], cards[1]), row(cards[2], cards[3])]);
        },
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: display(context, size: 18)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: context.c.fgMuted)),
          const SizedBox(height: 20),
          child,
        ]),
      );
}

// ---------------------------------------------------------------- Restaurant Profile

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({required this.profile});
  final Map<String, dynamic> profile;
  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late final fields = {
    for (final k in ['name', 'currency', 'timezone', 'address', 'phone', 'email']) k: TextEditingController(text: '${widget.profile[k] ?? ''}'),
  };
  Map<String, String> errors = {};
  bool submitting = false, saved = false;

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    final f = {for (final e in fields.entries) e.key: e.value.text};
    final errs = <String, String>{};
    if (f['name']!.trim().length < 2) errs['name'] = 'Restaurant name is required';
    if (f['email']!.isNotEmpty && !isEmail(f['email']!)) errs['email'] = 'Enter a valid email';
    setState(() => errors = errs);
    if (errs.isNotEmpty) return;
    setState(() {
      saved = false;
      submitting = true;
    });
    try {
      await Api.put('/settings/profile', f);
      if (mounted) setState(() => saved = true);
    } catch (err) {
      toast(err is ApiError ? err.message : '$err', error: true);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Section(
      title: 'Restaurant Profile',
      subtitle: 'Brand name, currency, and contact details.',
      child: Gap(gap: 16, children: [
        BizField(label: 'Restaurant name', controller: fields['name']!, error: errors['name']),
        Cols([
          BizField(label: 'Currency', controller: fields['currency']!, hint: 'USD'),
          BizField(label: 'Timezone', controller: fields['timezone']!, hint: 'America/New_York'),
        ]),
        BizField(label: 'Address', controller: fields['address']!),
        Cols([
          BizField(label: 'Phone', controller: fields['phone']!),
          BizField(label: 'Email', controller: fields['email']!, error: errors['email']),
        ]),
        Row(children: [
          Btn('Save changes', busy: submitting, onPressed: submit),
          if (saved) ...[
            const SizedBox(width: 12),
            Icon(LucideIcons.check, size: 16, color: c.success),
            const SizedBox(width: 4),
            Text('Saved', style: TextStyle(fontSize: 14, color: c.success)),
          ],
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Change Password

class _PasswordCard extends StatefulWidget {
  const _PasswordCard();
  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final current = TextEditingController();
  final next = TextEditingController();
  Map<String, String> errors = {};
  ({bool ok, String text})? msg;
  bool submitting = false;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final errs = <String, String>{};
    if (current.text.isEmpty) errs['currentPassword'] = 'Current password is required';
    if (next.text.length < 6) errs['newPassword'] = 'New password must be at least 6 characters';
    setState(() => errors = errs);
    if (errs.isNotEmpty) return;
    setState(() {
      msg = null;
      submitting = true;
    });
    dynamic res;
    try {
      res = await Api.post('/settings/password', {'currentPassword': current.text, 'newPassword': next.text});
    } catch (_) {
      res = {'ok': false, 'error': 'Something went wrong'};
    }
    if (!mounted) return;
    setState(() {
      if (res is Map && res['ok'] == true) {
        msg = (ok: true, text: 'Password updated');
        current.clear();
        next.clear();
      } else {
        msg = (ok: false, text: res is Map && res['error'] != null ? '${res['error']}' : 'Failed');
      }
      submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Section(
      title: 'Change Password',
      subtitle: 'Update your account password.',
      child: AutofillGroup(
        child: Gap(gap: 16, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (msg != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: msg!.ok ? c.successSoft : c.dangerSoft, borderRadius: BorderRadius.circular(8)),
              child: Text(msg!.text, style: TextStyle(fontSize: 14, color: msg!.ok ? c.success : c.danger)),
            ),
          BizField(
            label: 'Current password',
            controller: current,
            obscure: true,
            error: errors['currentPassword'],
            autofillHints: const [AutofillHints.password],
          ),
          BizField(
            label: 'New password',
            controller: next,
            obscure: true,
            error: errors['newPassword'],
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => submit(),
          ),
          Btn('Update password', busy: submitting, onPressed: submit),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Team

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.account});
  final List<Map<String, dynamic>> team;
  final Map<String, dynamic> account;

  static const _roleTones = {'OWNER': Tone.accent, 'MANAGER': Tone.info, 'STAFF': Tone.muted};

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Section(
      title: 'Team',
      subtitle: 'Signed in as ${account['name'] ?? 'User'} (${account['role'] ?? ''}).',
      child: Column(children: [
        for (final (i, m) in team.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m['name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('${m['email'] ?? ''}', style: TextStyle(fontSize: 12, color: c.fgMuted)),
                ]),
              ),
              if (_roleTones.containsKey(m['role']))
                ToneBadge('${m['role']}', tone: _roleTones[m['role']]!)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text('${m['role'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Roles & Permissions

/// app/Support/Rbac.php PERMISSIONS (OWNER = '*').
const _rbac = <String, List<String>>{
  'MANAGER': [
    'view:dashboard', 'manage:menu', 'manage:orders', 'manage:reservations', 'manage:tables', 'operate:floor', 'manage:coupons',
    'manage:outlets', 'manage:staff', 'manage:customers', 'manage:inventory', 'view:reports',
  ],
  'STAFF': ['view:dashboard', 'manage:orders', 'manage:reservations', 'operate:floor'],
};

bool _can(String role, String action) => role == 'OWNER' || (_rbac[role]?.contains(action) ?? false);

class _RolesCard extends StatelessWidget {
  const _RolesCard();

  static const _roles = ['OWNER', 'MANAGER', 'STAFF'];
  static const _actions = [
    ('view:dashboard', 'Dashboard'),
    ('manage:orders', 'Orders'),
    ('manage:menu', 'Menu'),
    ('manage:reservations', 'Reservations'),
    ('manage:outlets', 'Outlets'),
    ('manage:staff', 'Staff'),
    ('manage:customers', 'Customers'),
    ('manage:inventory', 'Inventory'),
    ('view:reports', 'Reports'),
    ('manage:settings', 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final head = TextStyle(fontSize: 11, letterSpacing: .6, fontWeight: FontWeight.w500, color: c.fgMuted);
    return _Section(
      title: 'Roles & Permissions',
      subtitle: 'What each role can access.',
      child: Table(
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            Padding(padding: const EdgeInsets.fromLTRB(0, 8, 12, 8), child: Text('MODULE', style: head)),
            for (final r in _roles) Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Text(r, textAlign: TextAlign.center, style: head)),
          ]),
          for (final (action, name) in _actions)
            TableRow(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(0, 8, 12, 8), child: Text(name, style: const TextStyle(fontSize: 14))),
                for (final r in _roles)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Center(
                      child: _can(r, action)
                          ? Icon(LucideIcons.check, size: 16, color: c.success)
                          : Text('—', style: TextStyle(fontSize: 14, color: c.fgMuted)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
