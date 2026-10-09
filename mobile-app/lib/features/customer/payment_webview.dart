import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'customer_providers.dart';

/// Runs the admin's configured gateway (Razorpay Checkout / Stripe Payment
/// Element) inside a WebView using the keys from POST /api/payment, and returns
/// the `payment` object the order / gift-card endpoints verify server-side.
Future<Json?> payOnline(
  BuildContext context,
  WidgetRef ref, {
  required String provider,
  required num amount,
  required String description,
}) async {
  final api = ref.read(apiProvider);
  final profile = ref.read(sessionProvider).profile;
  final Json init;
  try {
    init = await api.post('/api/payment', {'provider': provider, 'amount': amount, 'description': description});
  } catch (e) {
    if (context.mounted) toast(context, '$e', error: true);
    return null;
  }
  final html = provider == 'stripe'
      ? _stripeHtml(init['publishableKey'] as String, init['clientSecret'] as String, amount)
      : _razorpayHtml(init, description, profile);
  if (!context.mounted) return null;
  return Navigator.of(context).push<Json>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _PaymentPage(html: html, provider: provider),
  ));
}

class _PaymentPage extends StatefulWidget {
  const _PaymentPage({required this.html, required this.provider});
  final String html;
  final String provider;
  @override
  State<_PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<_PaymentPage> {
  late final WebViewController _web;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.ink)
      ..addJavaScriptChannel('Pay', onMessageReceived: (m) {
        if (!mounted) return;
        if (m.message == 'cancel') {
          Navigator.pop(context);
        } else if (m.message.startsWith('error:')) {
          toast(context, m.message.substring(6), error: true);
        } else {
          Navigator.pop(context, jsonDecode(m.message) as Json);
        }
      })
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => setState(() => _loading = false)))
      ..loadHtmlString(widget.html, baseUrl: '$kSiteOrigin/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.provider == 'stripe' ? 'Card payment' : 'Secure payment')),
      body: Stack(children: [
        WebViewWidget(controller: _web),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}

String _razorpayHtml(Json init, String description, Profile? p) {
  final opts = jsonEncode({
    'key': init['keyId'],
    'order_id': init['orderId'],
    'amount': init['amount'],
    'currency': init['currency'],
    'name': 'Go4Foodie',
    'description': description,
    'prefill': {'name': p?.name ?? '', 'email': p?.email ?? '', 'contact': p?.phone ?? ''},
    'theme': {'color': '#f5761e'},
  });
  return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{background:#0a1c18;color:#f7f1e8;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:90vh}</style>
<script src="https://checkout.razorpay.com/v1/checkout.js"></script></head>
<body><p>Opening secure checkout…</p><script>
var o = $opts;
o.handler = function(r){ Pay.postMessage(JSON.stringify({provider:'razorpay',orderId:r.razorpay_order_id,paymentId:r.razorpay_payment_id,signature:r.razorpay_signature})); };
o.modal = { ondismiss: function(){ Pay.postMessage('cancel'); } };
var rzp = new Razorpay(o);
rzp.on('payment.failed', function(r){ Pay.postMessage('error:' + (r.error && r.error.description || 'Payment failed')); });
rzp.open();
</script></body></html>''';
}

String _stripeHtml(String pk, String clientSecret, num amount) => '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://js.stripe.com/v3/"></script>
<style>
body{background:#0a1c18;color:#f7f1e8;font-family:-apple-system,Roboto,sans-serif;margin:0;padding:20px}
h2{font-family:Georgia,serif;font-weight:600;margin:4px 0 18px}
button{margin-top:22px;width:100%;height:52px;border:0;border-radius:999px;background:#f5761e;color:#0a1c18;font-weight:700;font-size:16px}
button:disabled{opacity:.5}#err{color:#f0766b;margin-top:12px}
</style></head><body>
<h2>Pay \$${amount.toStringAsFixed(2)}</h2><div id="pe"></div><button id="pay">Pay now</button><div id="err"></div>
<script>
var stripe = Stripe('$pk');
var elements = stripe.elements({clientSecret:'$clientSecret',appearance:{theme:'night',variables:{colorPrimary:'#f5761e',colorBackground:'#0f2621',borderRadius:'12px'}}});
elements.create('payment').mount('#pe');
document.getElementById('pay').onclick = async function(){
  this.disabled = true;
  var r = await stripe.confirmPayment({elements:elements, redirect:'if_required'});
  if (r.error) { document.getElementById('err').textContent = r.error.message; this.disabled = false; }
  else Pay.postMessage(JSON.stringify({provider:'stripe',paymentIntentId:r.paymentIntent.id}));
};
</script></body></html>''';

/// Payment method picker used by checkout & gift cards.
/// Returns 'restaurant' (pay later) or a gateway id.
class PaymentOptions extends ConsumerWidget {
  const PaymentOptions({super.key, required this.value, required this.onChanged, this.allowPayLater = true});
  final String value;
  final ValueChanged<String> onChanged;
  final bool allowPayLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateways = ref.watch(paymentConfigProvider).valueOrNull ?? const [];
    final options = <(String, IconData, String, String)>[
      if (allowPayLater) ('restaurant', Icons.storefront_rounded, 'Pay at restaurant', 'Settle at the counter or your table'),
      if (gateways.contains('razorpay')) ('razorpay', Icons.account_balance_wallet_rounded, 'Razorpay', 'UPI, cards, net-banking & wallets'),
      if (gateways.contains('stripe')) ('stripe', Icons.credit_card_rounded, 'Card (Stripe)', 'Visa, Mastercard, Amex'),
    ];
    return Column(children: [
      for (final o in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => onChanged(o.$1),
            borderColor: value == o.$1 ? context.c.accent : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(o.$2, color: context.c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(o.$4, style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                ]),
              ),
              Icon(value == o.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: value == o.$1 ? context.c.accent : context.c.muted),
            ]),
          ),
        ),
    ]);
  }
}
