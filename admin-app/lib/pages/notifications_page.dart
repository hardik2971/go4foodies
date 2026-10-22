import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// notifications/index.blade.php — recent activity list (orders, reservation requests, low stock, tables).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const _meta = {
    'order': (LucideIcons.shoppingBag, Tone.info),
    'reservation': (LucideIcons.calendarClock, Tone.accent),
    'stock': (LucideIcons.packageX, Tone.danger),
    'table': (LucideIcons.layoutDashboard, Tone.warn),
  };

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: () async {
          final d = await Api.get('/notifications');
          return [for (final n in (d['notifications'] as List? ?? const [])) Map<String, dynamic>.from(n)];
        },
        builder: (context, items, _) {
          final c = context.c;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 672),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
                      child: Text('You’re all caught up.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.fgMuted)),
                    ),
                  for (final (i, n) in items.indexed)
                    Builder(builder: (context) {
                      final (icon, tone) = _meta[n['type']] ?? _meta['order']!;
                      final t = toneColors(context, tone);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8)),
                            child: Icon(icon, size: 18, color: t.fg),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${n['title'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              Text('${n['detail'] ?? ''}', style: TextStyle(fontSize: 12, color: c.fgMuted)),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          // Server rendered 'M j, g:i A'.
                          Text(fmtDate(n['time'], 'MMM d, h:mm a'), style: TextStyle(fontSize: 12, color: c.fgMuted)),
                        ]),
                      );
                    }),
                ]),
              ),
            ),
          );
        },
      );
}
