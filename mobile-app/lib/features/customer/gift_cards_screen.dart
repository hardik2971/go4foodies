import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'customer_providers.dart';
import 'payment_webview.dart';

const _amounts = [10, 50, 100, 200, 250, 500, 750, 1000];

class GiftCardsScreen extends ConsumerWidget {
  const GiftCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gift Cards')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.goldBrand,
        foregroundColor: AppColors.ink,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuyGiftCardScreen())),
        icon: const Icon(Icons.card_giftcard_rounded),
        label: const Text('Buy', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: AsyncBody<List<Json>>(
        value: ref.watch(myGiftCardsProvider),
        onRefresh: () async => ref.refresh(myGiftCardsProvider.future),
        builder: (cards) => cards.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                EmptyState(icon: Icons.card_giftcard_outlined, title: 'No gift cards yet', message: 'Treat someone to an evening at Go4Foodie.'),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _GiftCard(card: cards[i]),
              ),
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.card});
  final Json card;
  @override
  Widget build(BuildContext context) {
    final coupon = card['kind'] == 'COUPON';
    return Container(
      height: 190,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF163A30), AppColors.ink], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: const Color(0x66F5761E)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const BrandLogo(height: 30, forceLight: true),
          const Spacer(),
          StatusChip(card['status'] as String),
        ]),
        const Spacer(),
        Text(coupon ? 'COUPON' : 'GIFT CARD', style: const TextStyle(color: AppColors.goldSoft, letterSpacing: 2.4, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(money(asNum(card['amount'])), style: display(context, size: 32, color: AppColors.cream)),
        const SizedBox(height: 8),
        Row(children: [
          Text(card['code'] as String, style: const TextStyle(color: AppColors.cream, letterSpacing: 2, fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.goldBrand),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: card['code'] as String));
              toast(context, 'Code copied');
            },
          ),
          const Spacer(),
          if (card['expiryDate'] != null) Text('Exp ${fmtDate(card['expiryDate'], 'd MMM y')}', style: const TextStyle(color: Color(0xFFA9BCB5), fontSize: 12)),
        ]),
      ]),
    );
  }
}

class BuyGiftCardScreen extends ConsumerStatefulWidget {
  const BuyGiftCardScreen({super.key});
  @override
  ConsumerState<BuyGiftCardScreen> createState() => _BuyGiftCardScreenState();
}

class _BuyGiftCardScreenState extends ConsumerState<BuyGiftCardScreen> {
  String _kind = 'GIFT_CARD';
  int _amount = 100;
  String _pay = '';
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    final gateways = ref.read(paymentConfigProvider).valueOrNull ?? const [];
    final provider = _pay.isEmpty ? gateways.firstOrNull : _pay;
    setState(() => _busy = true);
    try {
      Json? payment;
      if (provider != null) {
        payment = await payOnline(context, ref, provider: provider, amount: _amount, description: 'Gift card');
        if (payment == null) return;
      }
      final res = await ref.read(apiProvider).post('/api/mobile/customer/gift-cards', {
        'kind': _kind,
        'amount': _amount,
        if (_message.text.trim().isNotEmpty) 'message': _message.text.trim(),
        'payment': ?payment,
      });
      ref.invalidate(myGiftCardsProvider);
      if (!mounted) return;
      toast(context, 'Purchased · code ${res['code']}');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateways = ref.watch(paymentConfigProvider).valueOrNull ?? const [];
    if (_pay.isEmpty && gateways.isNotEmpty) _pay = gateways.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Buy a gift card')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'GIFT_CARD', label: Text('Gift card'), icon: Icon(Icons.card_giftcard_rounded)),
            ButtonSegment(value: 'COUPON', label: Text('Coupon'), icon: Icon(Icons.local_offer_rounded)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SectionTitle('Amount', padding: EdgeInsets.fromLTRB(4, 20, 4, 10)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in _amounts)
            ChoiceChip(label: Text(money(a)), selected: _amount == a, showCheckmark: false, onSelected: (_) => setState(() => _amount = a)),
        ]),
        const SizedBox(height: 18),
        TextField(controller: _message, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Personal message (optional)')),
        if (gateways.isNotEmpty) ...[
          const SectionTitle('Payment', padding: EdgeInsets.fromLTRB(4, 8, 4, 10)),
          PaymentOptions(value: _pay, allowPayLater: false, onChanged: (v) => setState(() => _pay = v)),
        ],
      ]),
      bottomSheet: Container(
        color: context.c.surface,
        padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
        child: FilledButton(
          onPressed: _busy ? null : _buy,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink))
              : Text('Pay ${money(_amount)}'),
        ),
      ),
    );
  }
}

/// Profile shortcut for customers.
extension GiftCardsNav on BuildContext {
  void openGiftCards() => Navigator.of(this).push(MaterialPageRoute(builder: (_) => const GiftCardsScreen()));
}

