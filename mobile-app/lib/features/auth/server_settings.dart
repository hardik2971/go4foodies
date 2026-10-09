import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// Lets testers point the app at another admin server (LAN IP / production).
Future<void> showServerSettings(BuildContext context, WidgetRef ref) async {
  final api = ref.read(apiProvider);
  final ctrl = TextEditingController(text: api.baseUrl);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Server address', style: display(ctx, size: 22)),
        const SizedBox(height: 6),
        Text('The admin backend shared by all three apps.', style: TextStyle(color: ctx.c.muted)),
        const SizedBox(height: 16),
        TextField(controller: ctrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Base URL')),
        const SizedBox(height: 8),
        TextButton(onPressed: () => ctrl.text = kDefaultBaseUrl, child: const Text('Use default server')),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            final v = ctrl.text.trim().replaceAll(RegExp(r'/+$'), '');
            if (Uri.tryParse(v)?.hasScheme != true) {
              toast(ctx, 'Enter a full URL, e.g. http://192.168.1.10:33664', error: true);
              return;
            }
            api.baseUrl = v;
            await ref.read(prefsProvider).setString('baseUrl', v);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ]),
    ),
  );
}
