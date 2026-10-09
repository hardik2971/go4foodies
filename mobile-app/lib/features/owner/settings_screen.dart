import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../staff/staff_providers.dart';

/// Restaurant settings (admin /settings): profile + admin team.
class RestaurantSettingsScreen extends ConsumerStatefulWidget {
  const RestaurantSettingsScreen({super.key});
  @override
  ConsumerState<RestaurantSettingsScreen> createState() => _RestaurantSettingsScreenState();
}

class _RestaurantSettingsScreenState extends ConsumerState<RestaurantSettingsScreen> {
  final _f = {for (final k in ['name', 'currency', 'timezone', 'address', 'phone', 'email']) k: TextEditingController()};
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant settings')),
      body: AsyncBody<Json>(
        value: ref.watch(settingsProvider),
        onRefresh: () async => ref.refresh(settingsProvider.future),
        builder: (data) {
          final profile = (data['profile'] as Json?) ?? const {};
          final team = ((data['team'] as List?) ?? const []).cast<Json>();
          if (!_loaded) {
            _f.forEach((k, c) => c.text = '${profile[k] ?? ''}');
            _loaded = true;
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Eyebrow('Profile'),
                const SizedBox(height: 12),
                TextField(controller: _f['name'], decoration: const InputDecoration(labelText: 'Restaurant name')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: _f['currency'], decoration: const InputDecoration(labelText: 'Currency'))),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: TextField(controller: _f['timezone'], decoration: const InputDecoration(labelText: 'Timezone'))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _f['address'], decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 10),
                TextField(controller: _f['phone'], decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 10),
                TextField(controller: _f['email'], decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await guard(context, () async {
                            await ref.read(apiProvider).put('$staffApi/settings', {for (final e in _f.entries) e.key: e.value.text.trim()});
                          }, success: 'Settings saved');
                          if (mounted) setState(() => _busy = false);
                        },
                  child: const Text('Save settings'),
                ),
              ]),
            ),
            const SectionTitle('Admin team', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final u in team)
                  ListTile(
                    leading: Avatar((u['name'] as String).isEmpty ? '?' : (u['name'] as String)[0], size: 38),
                    title: Text(u['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(u['email'] as String),
                    trailing: StatusChip(u['role'] as String, label: u['role'] as String),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            Text('Admin logins are managed in the web admin (Settings → Team).', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
          ]);
        },
      ),
    );
  }
}
