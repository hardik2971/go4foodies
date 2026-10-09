import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'staff_providers.dart';

const _couponStatuses = ['PENDING_PAYMENT', 'PAID', 'ACTIVE', 'REDEEMED', 'EXPIRED', 'CANCELLED'];

/// Gift cards & coupons (admin /gift-cards).
class GiftCardsAdminScreen extends ConsumerWidget {
  const GiftCardsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gift cards')),
      body: AsyncBody<List<Json>>(
        value: ref.watch(giftCardsAdminProvider),
        onRefresh: () async => ref.refresh(giftCardsAdminProvider.future),
        builder: (cards) {
          final active = cards.where((g) => g['status'] == 'ACTIVE').fold<num>(0, (s, g) => s + asNum(g['amount']));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Row(children: [
              Expanded(child: KpiTile(label: 'Issued', value: '${cards.length}', icon: Icons.card_giftcard_rounded)),
              const SizedBox(width: 10),
              Expanded(child: KpiTile(label: 'Active balance', value: moneyCompact(active), icon: Icons.account_balance_wallet_outlined, highlight: true)),
            ]),
            const SizedBox(height: 12),
            if (cards.isEmpty) const EmptyState(icon: Icons.card_giftcard_outlined, title: 'No gift cards yet'),
            for (final g in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(g['code'] as String, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: g['code'] as String));
                              toast(context, 'Copied');
                            },
                          ),
                        ]),
                        Text('${g['customerName']} · ${humanize(g['kind'] as String)} · ${fmtDate(g['createdAt'], 'd MMM y')}',
                            style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(asNum(g['amount'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      PopupMenuButton<String>(
                        tooltip: 'Change status',
                        onSelected: (s) => guard(context, () async {
                          await ref.read(apiProvider).patch('$staffApi/gift-cards/${g['id']}/status', {'status': s});
                          ref.invalidate(giftCardsAdminProvider);
                        }, success: '${g['code']} → ${humanize(s)}'),
                        itemBuilder: (_) => [for (final s in _couponStatuses) PopupMenuItem(value: s, child: Text(humanize(s)))],
                        child: StatusChip(g['status'] as String),
                      ),
                    ]),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Tables & QR codes (admin /tables).
class TablesAdminScreen extends ConsumerWidget {
  const TablesAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tables & QR')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.goldBrand,
        foregroundColor: AppColors.ink,
        onPressed: () => _form(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: AsyncBody<Json>(
        value: ref.watch(tablesAdminProvider),
        onRefresh: () async => ref.refresh(tablesAdminProvider.future),
        builder: (data) {
          final tables = ((data['tables'] as List?) ?? const []).cast<Json>();
          final site = ((data['websiteUrl'] as String?) ?? '').replaceAll(RegExp(r'/+$'), '');
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
            if (tables.isEmpty) const EmptyState(icon: Icons.table_restaurant_outlined, title: 'No tables yet'),
            for (final t in tables)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _form(context, ref, table: t),
                  child: Row(children: [
                    Text('T${t['number']}', style: display(context, size: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((t['name'] as String?) ?? 'Table ${t['number']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${t['orderCount'] ?? 0} QR orders', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                      ]),
                    ),
                    StatusChip(t['status'] as String, label: t['status'] == 'ACTIVE' ? 'QR on' : 'QR off'),
                    IconButton(
                      tooltip: 'Show QR',
                      icon: Icon(Icons.qr_code_2_rounded, color: context.c.accent),
                      onPressed: () => _qr(context, t, '$site/order?table=${t['code']}'),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  void _qr(BuildContext context, Json t, String url) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Table ${t['number']}', style: display(ctx, size: 24)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: QrImageView(data: url, size: 220, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink)),
            ),
            const SizedBox(height: 12),
            SelectableText('Code: ${t['code']}', style: TextStyle(color: ctx.c.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text('Guests scan this to order from the table (website or Customer app).', textAlign: TextAlign.center, style: TextStyle(color: ctx.c.muted, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }

  Future<void> _form(BuildContext context, WidgetRef ref, {Json? table}) async {
    final number = TextEditingController(text: table?['number'] as String? ?? '');
    final name = TextEditingController(text: table?['name'] as String? ?? '');
    var active = (table?['status'] ?? 'ACTIVE') == 'ACTIVE';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(table == null ? 'New table' : 'Edit table', style: display(ctx, size: 22)),
            const SizedBox(height: 14),
            TextField(controller: number, decoration: const InputDecoration(labelText: 'Table number (e.g. 12, Patio-3)')),
            const SizedBox(height: 10),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (optional)')),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('QR ordering enabled'), value: active, onChanged: (v) => set(() => active = v)),
            Row(children: [
              if (table != null)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: ctx.c.danger),
                  onPressed: () async {
                    if (!await confirm(ctx, title: 'Delete table ${table['number']}?', confirmLabel: 'Delete', destructive: true) || !ctx.mounted) return;
                    final ok = await guard(ctx, () async {
                      await ref.read(apiProvider).delete('$staffApi/tables/${table['id']}');
                      ref.invalidate(tablesAdminProvider);
                    });
                    if (ok && ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final body = {'number': number.text.trim(), 'name': name.text.trim(), 'status': active ? 'ACTIVE' : 'INACTIVE'};
                    final ok = await guard(ctx, () async {
                      final api = ref.read(apiProvider);
                      table == null ? await api.post('$staffApi/tables', body) : await api.put('$staffApi/tables/${table['id']}', body);
                      ref.invalidate(tablesAdminProvider);
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
    );
  }
}

/// Outlets overview (admin /outlets).
class OutletsScreen extends ConsumerWidget {
  const OutletsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outlets')),
      body: AsyncBody<List<Json>>(
        value: ref.watch(outletsProvider),
        onRefresh: () async => ref.refresh(outletsProvider.future),
        builder: (outlets) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          if (outlets.isEmpty) const EmptyState(icon: Icons.storefront_outlined, title: 'No outlets'),
          for (final o in outlets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Builder(builder: (context) {
                final weekly = ((o['weekly'] as List?) ?? const []).cast<Json>();
                final cur = weekly.isEmpty ? null : weekly.last;
                final rev = asNum(cur?['revenue']);
                final cost = asNum(cur?['cost']);
                return AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(o['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      StatusChip(o['isActive'] == true ? 'ACTIVE' : 'INACTIVE'),
                    ]),
                    Text('${o['location'] ?? ''} · ${o['manager'] ?? ''}', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: KeyValue('Revenue (wk)', money(rev))),
                      const SizedBox(width: 16),
                      Expanded(child: KeyValue('Margin', rev == 0 ? '—' : '${((rev - cost) / rev * 100).toStringAsFixed(0)}%', valueColor: rev >= cost ? context.c.success : context.c.danger)),
                    ]),
                  ]),
                );
              }),
            ),
        ]),
      ),
    );
  }
}
