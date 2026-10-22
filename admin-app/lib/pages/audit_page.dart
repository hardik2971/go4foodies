import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/biz_widgets.dart';
import '../widgets/ui.dart';

/// audit/index.blade.php — latest 200 POS & table actions.
class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  static const _actionTones = {
    'open': Tone.success,
    'close': Tone.accent,
    'add': Tone.info,
    'void': Tone.danger,
    'merge': Tone.warn,
    'state': Tone.muted,
    'payment': Tone.info,
  };

  /// Colour by the suffix after "." (or the whole action when there is none).
  static Tone _tone(String action) {
    final parts = action.split('.');
    final key = parts.length > 1 ? parts[1] : parts[0];
    return _actionTones[key] ?? Tone.muted;
  }

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: () async {
          final d = await Api.get('/audit');
          return [for (final l in (d['logs'] as List? ?? const [])) Map<String, dynamic>.from(l)];
        },
        builder: (context, logs, _) {
          final c = context.c;
          return BizTable(
            empty: 'No activity logged yet.',
            minWidth: 760,
            columns: const [
              DataCol('When', flex: 2),
              DataCol('Action', flex: 2),
              DataCol('Entity', flex: 2),
              DataCol('Detail', flex: 4),
              DataCol('By', flex: 2),
            ],
            rows: [
              for (final l in logs)
                BizRow([
                  // Server rendered 'M j, g:i A'.
                  Text(fmtDate(l['createdAt'], 'MMM d, h:mm a'), softWrap: false, style: TextStyle(fontSize: 14, color: c.fgMuted)),
                  ToneBadge('${l['action'] ?? ''}', tone: _tone('${l['action'] ?? ''}')),
                  CellText('${l['entity'] ?? ''}'),
                  CellText('${l['detail'] ?? '—'}', maxLines: 3),
                  CellText('${l['userName'] ?? 'System'}', muted: false),
                ]),
            ],
          );
        },
      );
}
