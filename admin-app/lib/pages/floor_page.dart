import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/ops_widgets.dart';
import '../widgets/ui.dart';

/// Floor plan (live) — port of resources/views/floor/index.blade.php (FloorPlan).
/// Live updates: Firestore listeners on tables / tableSessions / orders / payments replace the
/// 5 s `/floor/version` poll; 60 s safety refresh and 30 s duration clock are kept.
class FloorPage extends StatelessWidget {
  const FloorPage({super.key});
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => asJson(await Api.get('/floor')),
        builder: (context, data, _) => _FloorView(data: data),
      );
}

const _defaultStates = ['AVAILABLE', 'RESERVED', 'OCCUPIED', 'WAITING_PAYMENT', 'CLEANING', 'OUT_OF_SERVICE'];
const _stateLabels = {
  'AVAILABLE': 'Available',
  'RESERVED': 'Reserved',
  'OCCUPIED': 'Occupied',
  'WAITING_PAYMENT': 'Waiting Payment',
  'CLEANING': 'Cleaning',
  'OUT_OF_SERVICE': 'Out of Service',
};
const _watched = ['tables', 'tableSessions', 'orders', 'payments'];

class _FloorView extends StatefulWidget {
  const _FloorView({required this.data});
  final Json data;
  @override
  State<_FloorView> createState() => _FloorViewState();
}

class _FloorViewState extends State<_FloorView> {
  late List<Json> tables = asJsonList(widget.data['tables']);
  late final List<Json> waiters = asJsonList(widget.data['waiters']);
  late final List<String> states = List<String>.from((widget.data['states'] as List?) ?? _defaultStates);
  late final List<String> paymentMethods = List<String>.from((widget.data['paymentMethods'] as List?) ?? const ['Cash', 'Credit Card', 'Debit Card', 'UPI', 'Wallet', 'Mixed']);

  String? activeId;
  Json? activeSnapshot;
  BuildContext? modalCtx;
  DateTime now = DateTime.now();
  bool pending = false;
  final guests = TextEditingController(text: '2');
  final custName = TextEditingController();
  String waiterId = '';
  late String payMethod = paymentMethods.first;
  final rev = Rev();

  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _debounce;
  late final Ticker _clock, _safety;

  @override
  void initState() {
    super.initState();
    _clock = Ticker(const Duration(seconds: 30), () => update(() => now = DateTime.now()));
    _safety = Ticker(const Duration(seconds: 60), refresh);
    for (final name in _watched) {
      var first = true;
      _subs.add(FirebaseFirestore.instance.collection(name).snapshots().listen((_) {
        if (first) {
          first = false;
          return;
        }
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), refresh);
      }, onError: (Object _) {/* offline / rules — the 60 s refresh still runs */}));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _debounce?.cancel();
    _clock.cancel();
    _safety.cancel();
    guests.dispose();
    custName.dispose();
    rev.dispose();
    super.dispose();
  }

  void update(VoidCallback fn) {
    if (mounted) setState(fn);
    rev.bump();
  }

  Json? get active => activeId == null ? null : (tables.where((t) => t['id'] == activeId).firstOrNull ?? activeSnapshot);

  void setTables(List<Json> next) => update(() {
        tables = next;
        final a = activeId == null ? null : next.where((t) => t['id'] == activeId).firstOrNull;
        if (a != null) activeSnapshot = a;
      });

  Future<void> refresh() async {
    try {
      final res = asJson(await Api.get('/floor/data'));
      if (mounted) setTables(asJsonList(res['tables']));
    } catch (_) {/* keep current view */}
  }

  String fmtDuration(dynamic openedAt) => durationSince(openedAt, now);

  Future<void> select(Json t) async {
    setState(() {
      activeId = str(t['id']);
      activeSnapshot = t;
    });
    await showAppModal(context, title: 'Table ${t['number']}', builder: (ctx) {
      modalCtx = ctx;
      return synced(rev, () {
        final a = active;
        return a == null ? const SizedBox() : _detail(ctx, a);
      });
    });
    modalCtx = null;
    if (mounted) setState(() => activeId = null);
  }

  void closeModal() {
    final ctx = modalCtx;
    if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
  }

  Future<void> doOpen(Json t) async {
    update(() => pending = true);
    final g = guests.text.trim();
    try {
      await Api.post('/floor/tables/${t['id']}/open', {
        'customerCount': int.tryParse(g) ?? g,
        'waiterId': waiterId.isEmpty ? null : waiterId,
        'customerName': custName.text.isEmpty ? null : custName.text,
      });
    } catch (e) {
      toast('$e', error: true);
    }
    await refresh();
    closeModal();
    update(() => pending = false);
  }

  Future<void> doClose(Json t) async {
    final s = t['session'];
    if (s == null) return;
    update(() => pending = true);
    try {
      await Api.post('/floor/sessions/${s['id']}/close', {'paymentMethod': payMethod});
    } catch (e) {
      toast('$e', error: true);
    }
    await refresh();
    closeModal();
    update(() => pending = false);
  }

  void doState(Json t, String state) {
    update(() {
      tables = [for (final x in tables) x['id'] == t['id'] ? {...x, 'state': state} : x];
      if (activeSnapshot != null && activeSnapshot!['id'] == t['id']) activeSnapshot = {...activeSnapshot!, 'state': state};
    });
    guard(() => Api.patch('/floor/tables/${t['id']}/state', {'state': state}));
  }

  ({Color border, Color bg}) cardColors(String state) {
    final c = context.c;
    return switch (state) {
      'AVAILABLE' => (border: c.success.withValues(alpha: .4), bg: Color.alphaBlend(c.successSoft.withValues(alpha: .5), c.surface)),
      'RESERVED' => (border: c.warn.withValues(alpha: .4), bg: Color.alphaBlend(c.warnSoft.withValues(alpha: .5), c.surface)),
      'OCCUPIED' => (border: c.danger.withValues(alpha: .4), bg: Color.alphaBlend(c.dangerSoft.withValues(alpha: .5), c.surface)),
      'WAITING_PAYMENT' => (border: c.accent.withValues(alpha: .5), bg: Color.alphaBlend(c.accentSoft.withValues(alpha: .6), c.surface)),
      'CLEANING' => (border: c.info.withValues(alpha: .4), bg: c.infoSoft),
      _ => (border: c.border, bg: c.bg),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final counts = <String, int>{'total': tables.length, for (final s in states) s: 0};
    for (final t in tables) {
      counts[str(t['state'])] = (counts[str(t['state'])] ?? 0) + 1;
    }
    final stats = <(String, String, Color)>[
      ('total', 'Total', c.fg),
      ('AVAILABLE', 'Available', c.success),
      ('OCCUPIED', 'Occupied', c.danger),
      ('RESERVED', 'Reserved', c.warn),
      ('WAITING_PAYMENT', 'Awaiting Pay', const Color(0xFFB45309)),
      ('CLEANING', 'Cleaning', c.info),
      ('OUT_OF_SERVICE', 'Out of Service', c.fgMuted),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Wrap(spacing: 32, runSpacing: 12, children: [
              for (final s in stats)
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${counts[s.$1] ?? 0}', style: display(context, size: 24, color: s.$3)),
                  Muted(s.$2, size: 12),
                ]),
            ]),
          ),
          const SizedBox(width: 12),
          Btn('Refresh', kind: BtnKind.ghost, icon: LucideIcons.refreshCw, small: true, onPressed: refresh),
        ]),
      ),
      const SizedBox(height: 20),
      if (tables.isEmpty)
        AppCard(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 64), child: Center(child: Muted('No tables yet — add tables in Table Management.', size: 14)))
      else
        ColsGrid(cols: (w) => colsFor(w, xl: 5), children: [for (final t in tables) _card(t)]),
    ]);
  }

  Widget _card(Json t) {
    final c = context.c;
    final st = str(t['state']);
    final col = cardColors(st);
    final s = t['session'] == null ? null : asJson(t['session']);
    Widget line(IconData icon, String text, {bool strong = false}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(icon, size: 14, color: strong ? c.fg : c.fgMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: strong ? c.fg : c.fgMuted, fontWeight: strong ? FontWeight.w600 : FontWeight.w400))),
          ]),
        );
    return _Lift(
      onTap: () => select(t),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: col.bg, border: Border.all(color: col.border), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Table ${t['number']}', style: display(context, size: 18)),
                if (has(t['name'])) Muted(str(t['name']), size: 12),
              ]),
            ),
            toneBadge(context, st, _stateLabels[st] ?? st, size: 10),
          ]),
          const SizedBox(height: 8),
          if (s != null) ...[
            line(LucideIcons.users, '${s['customerCount']} guests${has(s['waiterName']) ? ' · ${s['waiterName']}' : ''}'),
            line(LucideIcons.clock, '${fmtDuration(s['openedAt'])} · ${s['orderCount']} orders'),
            line(LucideIcons.receipt, money(s['currentBill']), strong: true),
          ] else
            Padding(padding: const EdgeInsets.only(top: 4), child: Muted('Seats ${t['capacity']}', size: 12)),
        ]),
      ),
    );
  }

  Widget _detail(BuildContext ctx, Json a) {
    final st = str(a['state']);
    final s = a['session'] == null ? null : asJson(a['session']);
    const gap = SizedBox(height: 20);
    void go(String path) {
      Navigator.of(ctx).pop();
      context.go(path);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        toneBadge(ctx, st, _stateLabels[st] ?? st, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
        const Spacer(),
        if (has(a['name'])) Muted('${a['name']} · seats ${a['capacity']}', size: 14),
      ]),
      gap,
      Row(children: [
        Expanded(child: Btn('Open POS ${s != null ? '· ${money(s['currentBill'])}' : ''}'.trim(), icon: LucideIcons.receipt, expand: true, onPressed: () => go('/pos/${a['id']}'))),
        const SizedBox(width: 8),
        Btn('History', kind: BtnKind.ghost, onPressed: () => go('/table-history/${a['id']}')),
      ]),
      gap,
      if (s != null) ...[
        TwoCol(stretch: true, children: [
          DetailBox('Guests', '${s['customerCount']}'),
          DetailBox('Waiter', has(s['waiterName']) ? str(s['waiterName']) : '—'),
          DetailBox('Duration', fmtDuration(s['openedAt'])),
          DetailBox('Orders', '${s['orderCount']}'),
          DetailBox('Customer', has(s['customerName']) ? str(s['customerName']) : '—'),
          DetailBox('Current bill', money(s['currentBill'])),
        ]),
        gap,
        Boxed(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Caption('Close & pay'),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              AppSelect<String>(value: payMethod, items: [for (final m in paymentMethods) (m, m)], onChanged: (v) => update(() => payMethod = v)),
              Btn('Close table · ${money(s['currentBill'])}', onPressed: pending ? null : () => doClose(a)),
              if (st != 'WAITING_PAYMENT') Btn('Awaiting payment', kind: BtnKind.ghost, onPressed: () => doState(a, 'WAITING_PAYMENT')),
            ]),
          ]),
        ),
      ] else
        Boxed(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Caption('Open table', bottom: 12),
            TwoCol(children: [
              SmallField(label: 'Guests', controller: guests, number: true),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Muted('Waiter', size: 12)),
                AppSelect<String>(
                  value: waiterId,
                  width: double.infinity,
                  items: [('', '— None —'), for (final w in waiters) (str(w['id']), str(w['name']))],
                  onChanged: (v) => update(() => waiterId = v),
                ),
              ]),
            ]),
            const SizedBox(height: 12),
            SmallField(label: 'Customer name (optional)', controller: custName, hint: 'Walk-in'),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Btn('Open & seat', icon: LucideIcons.userRound, onPressed: pending ? null : () => doOpen(a))),
          ]),
        ),
      gap,
      const Caption('Set state'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final x in states.where((x) => x != st)) _stateChip(ctx, a, x, disabled: s != null && (x == 'AVAILABLE' || x == 'OUT_OF_SERVICE')),
      ]),
    ]);
  }

  Widget _stateChip(BuildContext ctx, Json a, String x, {required bool disabled}) {
    final t = toneColors(ctx, statusTones[x] ?? Tone.muted);
    final chip = Opacity(
      opacity: disabled ? .4 : 1,
      child: Material(
        color: t.bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          mouseCursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
          onTap: disabled ? null : () => doState(a, x),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: ctx.c.border)),
            child: Text(_stateLabels[x] ?? x, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.fg)),
          ),
        ),
      ),
    );
    return disabled ? Tooltip(message: 'Close the open session first', child: chip) : chip;
  }
}

/// Hover lift (`hover:-translate-y-0.5`).
class _Lift extends StatefulWidget {
  const _Lift({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_Lift> createState() => _LiftState();
}

class _LiftState extends State<_Lift> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedSlide(offset: Offset(0, hover ? -0.015 : 0), duration: const Duration(milliseconds: 150), child: widget.child),
        ),
      );
}
