import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../auth/server_settings.dart';
import '../customer/gift_cards_screen.dart';

/// Account screen shared by all three apps (sections vary by login).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.extra = const []});
  final List<Widget> extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final p = s.profile;
    if (p == null) return const SizedBox.shrink();
    final c = context.c;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        AppCard(
          child: Row(children: [
            Avatar(p.initials, size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: display(context, size: 22)),
                const SizedBox(height: 2),
                Text(p.email, style: TextStyle(color: c.muted)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text('${s.role?.label ?? ''} · ${p.kind == 'customer' ? 'Member' : p.title}',
                      style: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ]),
            ),
          ]),
        ),
        if (p.kind == 'employee') ...[
          const SectionTitle('Duty status', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
          _DutySelector(current: p.dutyStatus ?? 'OFF'),
        ],
        ...extra,
        const SectionTitle('Account', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
        _Group(children: [
          _Tile(icon: Icons.person_outline_rounded, title: 'Edit profile', onTap: () => _editProfile(context, ref, p)),
          _Tile(icon: Icons.lock_outline_rounded, title: 'Change password', onTap: () => _changePassword(context, ref)),
          if (p.kind == 'customer')
            _Tile(icon: Icons.card_giftcard_rounded, title: 'Gift cards & coupons', onTap: () => context.openGiftCards()),
        ]),
        const SectionTitle('Preferences', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
        _Group(children: [
          SwitchListTile(
            secondary: Icon(Icons.dark_mode_outlined, color: c.accent),
            title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
            value: mode == ThemeMode.dark,
            onChanged: (v) {
              ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
              ref.read(prefsProvider).setString('themeMode', v ? 'dark' : 'light');
            },
          ),
          _Tile(icon: Icons.dns_outlined, title: 'Server address', onTap: () => showServerSettings(context, ref)),
        ]),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const Key('sign-out'),
          style: OutlinedButton.styleFrom(foregroundColor: c.danger, side: BorderSide(color: c.danger.withValues(alpha: 0.5))),
          onPressed: () async {
            if (await confirm(context, title: 'Sign out?', confirmLabel: 'Sign out', destructive: true)) {
              await ref.read(sessionProvider.notifier).signOut();
            }
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 18),
        Center(child: Text('Go4Foodie · v1.0.0', style: TextStyle(color: c.muted, fontSize: 12))),
      ]),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref, Profile p) async {
    final name = TextEditingController(text: p.name);
    final phone = TextEditingController(text: p.phone);
    final address = TextEditingController(text: p.address);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Edit profile', style: display(ctx, size: 22)),
          const SizedBox(height: 16),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          if (p.kind != 'user') ...[
            const SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
          ],
          if (p.kind == 'customer') ...[
            const SizedBox(height: 12),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => guard(ctx, () async {
              final res = await ref.read(apiProvider).put('/api/mobile/auth/me', {'name': name.text, 'phone': phone.text, 'address': address.text});
              ref.read(sessionProvider.notifier).updateProfile(res['user'] as Map<String, dynamic>);
              if (ctx.mounted) Navigator.pop(ctx);
            }, success: 'Profile updated'),
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Change password', style: display(ctx, size: 22)),
          const SizedBox(height: 16),
          TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
          const SizedBox(height: 12),
          TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password (min 6)')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => guard(ctx, () async {
              await ref.read(apiProvider).post('/api/mobile/auth/password', {'currentPassword': current.text, 'newPassword': next.text});
              if (ctx.mounted) Navigator.pop(ctx);
            }, success: 'Password changed'),
            child: const Text('Update password'),
          ),
        ]),
      ),
    );
  }
}

class _DutySelector extends ConsumerWidget {
  const _DutySelector({required this.current});
  final String current;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const opts = ['ON_DUTY', 'ON_BREAK', 'OFF'];
    return SegmentedButton<String>(
      segments: [for (final o in opts) ButtonSegment(value: o, label: Text(o == 'ON_DUTY' ? 'On duty' : o == 'ON_BREAK' ? 'Break' : 'Off'))],
      selected: {opts.contains(current) ? current : 'OFF'},
      onSelectionChanged: (s) => guard(context, () async {
        await ref.read(apiProvider).patch('/api/mobile/staff/me/duty', {'status': s.first});
        await ref.read(sessionProvider.notifier).refreshProfile();
      }, success: 'Status updated'),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(indent: 56),
          ],
        ]),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: context.c.accent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right_rounded, color: context.c.muted),
        onTap: onTap,
      );
}
