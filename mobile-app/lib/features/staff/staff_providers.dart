import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/session.dart';

typedef Json = Map<String, dynamic>;

const staffApi = '/api/mobile/staff';

/// GET /api/mobile/staff/{path} → the `key` list from the response.
AutoDisposeFutureProvider<List<Json>> _list(String path, String key) => FutureProvider.autoDispose<List<Json>>((ref) async {
      final res = await ref.read(apiProvider).get('$staffApi/$path');
      return ((res[key] as List?) ?? const []).cast<Json>();
    });

final floorProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('$staffApi/floor'));
final staffOrdersProvider = _list('orders', 'orders');
final staffReservationsProvider = _list('reservations', 'reservations');
final inventoryProvider = _list('inventory', 'items');
final customersProvider = _list('customers', 'customers');
final giftCardsAdminProvider = _list('gift-cards', 'giftCards');
final transactionsProvider = _list('transactions', 'transactions');
final notificationsProvider = _list('notifications', 'notifications');
final auditProvider = _list('audit', 'logs');
final outletsProvider = _list('outlets', 'outlets');

final staffMenuProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('$staffApi/menu'));
final staffListProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('$staffApi/staff'));
final tablesAdminProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('$staffApi/tables'));
final dashboardProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('$staffApi/dashboard'));
final settingsProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('$staffApi/settings'));

final reportsProvider = FutureProvider.autoDispose<Json>((ref) async {
  final res = await ref.read(apiProvider).get('$staffApi/reports');
  return res['reports'] as Json;
});

final tableAnalyticsProvider = FutureProvider.autoDispose.family<Json, int>((ref, days) async {
  final res = await ref.read(apiProvider).get('$staffApi/table-analytics', query: {'days': '$days'});
  return res['analytics'] as Json;
});

final tableHistoryProvider = FutureProvider.autoDispose.family<Json, String>((ref, tableId) async {
  final res = await ref.read(apiProvider).get('$staffApi/table-history/$tableId');
  return res['history'] as Json;
});

/// POS state for one table; mutations return the fresh POS view, which is
/// written straight back into the provider.
final posProvider = AsyncNotifierProvider.autoDispose.family<PosController, Json, String>(PosController.new);

class PosController extends AutoDisposeFamilyAsyncNotifier<Json, String> {
  Api get _api => ref.read(apiProvider);

  @override
  Future<Json> build(String tableId) => _api.get('$staffApi/pos/$tableId');

  Future<void> refresh() async => state = AsyncData(await _api.get('$staffApi/pos/$arg'));

  Future<void> _run(Future<Json> Function() call) async {
    final next = await call();
    state = AsyncData(next);
  }

  String get _sessionId => ((state.valueOrNull?['session'] as Json?)?['id'] as String?) ?? '';

  Future<void> open({required int guests, String? waiterId, String? customerName}) => _run(() => _api.post(
        '$staffApi/pos/$arg/open',
        {'customerCount': guests, 'waiterId': waiterId, 'customerName': customerName},
      ));

  Future<void> addItems(List<Json> items) => _run(() => _api.post('$staffApi/sessions/$_sessionId/items', {'items': items}));
  Future<void> voidItem(String menuItemId) => _run(() => _api.post('$staffApi/sessions/$_sessionId/void', {'menuItemId': menuItemId}));
  Future<void> billing(Json b) => _run(() => _api.put('$staffApi/sessions/$_sessionId/billing', b));
  Future<void> pay(num amount, String method) => _run(() => _api.post('$staffApi/sessions/$_sessionId/payments', {'amount': amount, 'method': method}));
  Future<void> close(String method) => _run(() => _api.post('$staffApi/sessions/$_sessionId/close', {'paymentMethod': method}));
  Future<void> mergeInto(String intoSessionId) => _run(() => _api.post('$staffApi/sessions/$_sessionId/merge', {'intoSessionId': intoSessionId}));
}

const paymentMethods = ['Cash', 'Credit Card', 'Debit Card', 'UPI', 'Wallet'];
const tableStates = ['AVAILABLE', 'RESERVED', 'OCCUPIED', 'WAITING_PAYMENT', 'CLEANING', 'OUT_OF_SERVICE'];
