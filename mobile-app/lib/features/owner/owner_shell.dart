import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/profile_screen.dart';
import '../staff/floor_screen.dart';
import '../staff/manage_hub.dart';
import 'dashboard_screen.dart';
import 'reports_screen.dart';

final ownerTabProvider = StateProvider<int>((_) => 0);

/// Owner app: dashboard, live floor, reports and every admin module.
class OwnerShell extends ConsumerWidget {
  const OwnerShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(ownerTabProvider);
    const pages = [
      DashboardScreen(),
      FloorScreen(),
      ReportsScreen(),
      ManageHub(exclude: ['Floor & POS', 'Reports']),
      ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(ownerTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.table_restaurant_outlined), selectedIcon: Icon(Icons.table_restaurant_rounded), label: 'Floor'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Manage'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}
