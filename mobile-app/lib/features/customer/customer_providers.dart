import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';

typedef Json = Map<String, dynamic>;

class MenuItem {
  MenuItem(this.raw);
  final Json raw;
  String get id => raw['id'] as String;
  String get name => raw['name'] as String;
  String get description => (raw['description'] as String?) ?? '';
  num get price => asNum(raw['price']);
  num get rating => asNum(raw['rating']);
  String get tag => (raw['tag'] as String?) ?? '';
  String get category => (raw['category'] as String?) ?? '';
  String get imageUrl => (raw['imageUrl'] as String?) ?? '';
}

class MenuData {
  MenuData(this.items, this.categories);
  final List<MenuItem> items;
  final List<String> categories;
}

/// Public storefront menu (same feed as the website: available items only).
final menuProvider = FutureProvider<MenuData>((ref) async {
  final res = await ref.read(apiProvider).get('/api/menu');
  return MenuData(
    ((res['items'] as List?) ?? const []).map((e) => MenuItem(e as Json)).toList(),
    ((res['categories'] as List?) ?? const []).cast<String>(),
  );
});

const _c = '/api/mobile/customer';

final customerHomeProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('$_c/home'));

final myOrdersProvider = FutureProvider.autoDispose<List<Json>>((ref) async {
  final res = await ref.read(apiProvider).get('$_c/orders');
  return ((res['orders'] as List?) ?? const []).cast<Json>();
});

final orderDetailProvider = FutureProvider.autoDispose.family<Json, String>((ref, id) async {
  final res = await ref.read(apiProvider).get('$_c/orders/$id');
  return res['order'] as Json;
});

final myReservationsProvider = FutureProvider.autoDispose<List<Json>>((ref) async {
  final res = await ref.read(apiProvider).get('$_c/reservations');
  return ((res['reservations'] as List?) ?? const []).cast<Json>();
});

final myGiftCardsProvider = FutureProvider.autoDispose<List<Json>>((ref) async {
  final res = await ref.read(apiProvider).get('$_c/gift-cards');
  return ((res['giftCards'] as List?) ?? const []).cast<Json>();
});

/// Which online gateways the admin has configured.
final paymentConfigProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final res = await ref.read(apiProvider).get('/api/payment');
  // PayPal needs its JS buttons pop-up flow, which isn't supported in-app.
  return ['razorpay', 'stripe'].where((p) => res[p] == true).toList();
});

// ---------------- Cart ----------------

class CartLine {
  const CartLine(this.item, this.qty);
  final MenuItem item;
  final int qty;
  num get total => item.price * qty;
}

class TableContext {
  const TableContext({required this.code, required this.number, this.name});
  final String code;
  final String number;
  final String? name;
}

class CartState {
  const CartState({this.lines = const {}, this.table});
  final Map<String, CartLine> lines;
  final TableContext? table; // set after scanning a table QR → dine-in order
  int get count => lines.values.fold(0, (s, l) => s + l.qty);
  num get total => lines.values.fold<num>(0, (s, l) => s + l.total);
  bool get isEmpty => lines.isEmpty;
  int qtyOf(String id) => lines[id]?.qty ?? 0;
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(MenuItem item, [int n = 1]) {
    final next = Map.of(state.lines);
    next[item.id] = CartLine(item, (next[item.id]?.qty ?? 0) + n);
    state = CartState(lines: next, table: state.table);
  }

  void remove(String id) {
    final next = Map.of(state.lines);
    final l = next[id];
    if (l == null) return;
    if (l.qty <= 1) {
      next.remove(id);
    } else {
      next[id] = CartLine(l.item, l.qty - 1);
    }
    state = CartState(lines: next, table: state.table);
  }

  void setTable(TableContext? t) => state = CartState(lines: state.lines, table: t);
  void clear({bool keepTable = false}) => state = CartState(table: keepTable ? state.table : null);

  List<Json> payloadItems() =>
      state.lines.values.map((l) => {'menuItemId': l.item.id, 'name': l.item.name, 'qty': l.qty}).toList();
}

/// Pickup slots — mirrors admin/src/lib/scheduling.ts (10:00–21:30, 30 min,
/// at least 30 min lead time).
List<String> pickupSlots(DateTime day) {
  final now = DateTime.now();
  final slots = <String>[];
  for (var m = 10 * 60; m <= 21 * 60 + 30; m += 30) {
    final t = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
    if (t.isAfter(now.add(const Duration(minutes: 30)))) {
      slots.add('${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
    }
  }
  return slots;
}
