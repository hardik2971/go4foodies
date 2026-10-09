import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'customer_providers.dart';
import 'customer_shell.dart';

/// Scan the table QR (…/order?table=<code>) — or type the code — to start a
/// dine-in order that lands on that table's bill.
class TableScanScreen extends ConsumerStatefulWidget {
  const TableScanScreen({super.key});
  @override
  ConsumerState<TableScanScreen> createState() => _TableScanScreenState();
}

class _TableScanScreenState extends ConsumerState<TableScanScreen> {
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;

  static String codeFrom(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri?.queryParameters['table'] ?? raw.trim();
  }

  Future<void> _resolve(String raw) async {
    if (_busy) return;
    final code = codeFrom(raw);
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiProvider).get('/api/mobile/customer/tables/${Uri.encodeComponent(code)}');
      final t = res['table'] as Map<String, dynamic>;
      ref.read(cartProvider.notifier).setTable(TableContext(code: t['code'] as String, number: '${t['number']}', name: t['name'] as String?));
      ref.read(customerTabProvider.notifier).state = 1; // → Menu
      if (mounted) {
        toast(context, 'Welcome to table ${t['number']} — add dishes to send to the kitchen');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manual() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter table code', style: display(ctx, size: 20)),
        content: TextField(
          key: const Key('table-code'),
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Code printed under the QR'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Continue')),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) await _resolve(code);
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Scan table QR')),
      body: Stack(children: [
        MobileScanner(
          controller: _scanner,
          onDetect: (capture) {
            final v = capture.barcodes.firstOrNull?.rawValue;
            if (v != null) _resolve(v);
          },
          errorBuilder: (_, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Camera unavailable (${error.errorCode.name}). Enter the table code instead.',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(border: Border.all(color: AppColors.goldBrand, width: 3), borderRadius: BorderRadius.circular(28)),
          ),
        ),
        if (_busy) const Center(child: CircularProgressIndicator()),
        Positioned(
          left: 24,
          right: 24,
          bottom: 32,
          child: SafeArea(
            child: Column(children: [
              const Text('Point your camera at the QR code on your table', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const Key('enter-code'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                onPressed: _manual,
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('Enter code manually'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
