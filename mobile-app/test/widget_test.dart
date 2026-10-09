import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go4foodie/core/api.dart';
import 'package:go4foodie/core/format.dart';
import 'package:go4foodie/core/session.dart';
import 'package:go4foodie/core/theme.dart';
import 'package:go4foodie/features/auth/role_select_screen.dart';
import 'package:go4foodie/features/customer/customer_providers.dart';
import 'package:go4foodie/features/staff/orders_board_screen.dart';
import 'package:go4foodie/features/staff/reservations_screen.dart';

MenuItem item(String id, num price) => MenuItem({'id': id, 'name': 'Dish $id', 'price': price, 'category': 'Starters'});

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('cart', () {
    test('adds, removes and totals lines', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final cart = c.read(cartProvider.notifier);
      cart.add(item('a', 12.5));
      cart.add(item('a', 12.5));
      cart.add(item('b', 4));
      expect(c.read(cartProvider).count, 3);
      expect(c.read(cartProvider).total, 29);
      cart.remove('a');
      expect(c.read(cartProvider).qtyOf('a'), 1);
      expect(cart.payloadItems(), hasLength(2));
    });

    test('keeps the table when cleared after a table order', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final cart = c.read(cartProvider.notifier)
        ..setTable(const TableContext(code: 'abc', number: '7'))
        ..add(item('a', 1));
      cart.clear(keepTable: true);
      expect(c.read(cartProvider).isEmpty, isTrue);
      expect(c.read(cartProvider).table?.number, '7');
    });
  });

  group('scheduling & workflow (mirrors admin rules)', () {
    test('pickup slots are 30 min apart within 10:00–21:30', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final slots = pickupSlots(tomorrow);
      expect(slots.first, '10:00');
      expect(slots.last, '21:30');
      expect(slots, hasLength(24));
    });

    test('order status flow', () {
      expect(nextOrderStatus('PENDING'), 'PREPARING');
      expect(nextOrderStatus('READY'), 'COMPLETED');
      expect(nextOrderStatus('COMPLETED'), isNull);
    });

    test('reservation transitions', () {
      expect(nextReservationStatuses('TABLE', 'CONFIRMED'), ['SEATED', 'CANCELED', 'NO_SHOW']);
      expect(nextReservationStatuses('PRIVATE_EVENT', 'CONFIRMED'), ['COMPLETED', 'CANCELED']);
      expect(nextReservationStatuses('TABLE', 'NO_SHOW'), isEmpty);
    });
  });

  group('helpers', () {
    test('format', () {
      expect(money(1234.5), r'$1,234.50');
      expect(humanize('WAITING_PAYMENT'), 'Waiting Payment');
      expect(fmtSlot('18:30'), '6:30 PM');
    });

    test('rewrites loopback image urls onto the configured server', () {
      final api = Api('http://10.0.2.2:33664');
      expect(api.image('http://127.0.0.1:33664/api/uploads/x.jpg'), 'http://10.0.2.2:33664/api/uploads/x.jpg');
      expect(api.image('/api/uploads/y.png'), 'http://10.0.2.2:33664/api/uploads/y.png');
      expect(api.image('https://images.unsplash.com/p'), 'https://images.unsplash.com/p');
    });

    test('profile permissions & roles', () {
      final p = Profile({'id': '1', 'name': 'Priya Shah', 'permissions': ['manage:orders']});
      expect(p.initials, 'PS');
      expect(p.can('manage:orders'), isTrue);
      expect(p.can('manage:settings'), isFalse);
      expect(AppRole.parse('owner'), AppRole.owner);
      expect(AppRole.restaurant.home, '/r');
    });
  });

  testWidgets('role picker offers all three apps', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(theme: buildTheme(Brightness.dark), home: const RoleSelectScreen()),
    ));
    expect(find.text('Customer App'), findsOneWidget);
    expect(find.text('Restaurant App'), findsOneWidget);
    expect(find.text('Owner App'), findsOneWidget);
  });
}
