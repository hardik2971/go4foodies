import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/profile_screen.dart';
import '../staff/floor_screen.dart';
import '../staff/manage_hub.dart';
import '../staff/menu_admin_screen.dart';
import '../staff/orders_board_screen.dart';
import '../staff/reservations_screen.dart';

final restaurantTabProvider = StateProvider<int>((_) => 0);

/// Restaurant (staff) app: floor & POS, kitchen orders, reservations, menu.
class RestaurantShell extends ConsumerWidget {
  const RestaurantShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(restaurantTabProvider);
    final pending = ref.watch(pendingOrdersCountProvider);
    const pages = [
      FloorScreen(),
      OrdersBoardScreen(),
      StaffReservationsScreen(),
      MenuAdminScreen(),
      ProfileScreen(extra: [ModuleList(titles: ['Inventory', 'Customers', 'Gift cards', 'Staff', 'Tables & QR', 'Reports', 'Activity'])]),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(restaurantTabProvider.notifier).state = i,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.table_restaurant_outlined), selectedIcon: Icon(Icons.table_restaurant_rounded), label: 'Floor'),
          NavigationDestination(
            icon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.receipt_long_outlined)),
            selectedIcon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.receipt_long_rounded)),
            label: 'Orders',
          ),
          const NavigationDestination(icon: Icon(Icons.event_seat_outlined), selectedIcon: Icon(Icons.event_seat_rounded), label: 'Bookings'),
          const NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu_rounded), label: 'Menu'),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}
