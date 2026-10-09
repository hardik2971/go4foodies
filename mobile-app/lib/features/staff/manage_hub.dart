import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../owner/activity_screen.dart';
import '../owner/reports_screen.dart';
import '../owner/settings_screen.dart';
import 'business_screens.dart';
import 'floor_screen.dart';
import 'inventory_screen.dart';
import 'menu_admin_screen.dart';
import 'orders_board_screen.dart';
import 'reservations_screen.dart';
import 'team_screen.dart';

class Module {
  const Module(this.title, this.subtitle, this.icon, this.action, this.builder);
  final String title, subtitle;
  final IconData icon;
  final String action; // RBAC permission required
  final WidgetBuilder builder;
}

final allModules = <Module>[
  Module('Orders', 'Kitchen & service board', Icons.receipt_long_rounded, 'manage:orders', (_) => const OrdersBoardScreen()),
  Module('Floor & POS', 'Tables, bills, payments', Icons.table_restaurant_rounded, 'manage:orders', (_) => const FloorScreen()),
  Module('Reservations', 'Bookings & events', Icons.event_seat_rounded, 'manage:reservations', (_) => const StaffReservationsScreen()),
  Module('Menu', 'Dishes, prices, availability', Icons.restaurant_menu_rounded, 'manage:menu', (_) => const MenuAdminScreen()),
  Module('Inventory', 'Stock & reorder levels', Icons.inventory_2_rounded, 'manage:inventory', (_) => const InventoryScreen()),
  Module('Staff', 'Team & duty status', Icons.badge_rounded, 'manage:staff', (_) => const TeamScreen()),
  Module('Customers', 'CRM & history', Icons.people_alt_rounded, 'manage:customers', (_) => const CustomersScreen()),
  Module('Gift cards', 'Cards & coupons', Icons.card_giftcard_rounded, 'manage:coupons', (_) => const GiftCardsAdminScreen()),
  Module('Tables & QR', 'Table list & QR codes', Icons.qr_code_2_rounded, 'manage:tables', (_) => const TablesAdminScreen()),
  Module('Reports', 'Sales, tables, transactions', Icons.bar_chart_rounded, 'view:reports', (_) => const ReportsScreen()),
  Module('Outlets', 'Locations & margins', Icons.storefront_rounded, 'manage:outlets', (_) => const OutletsScreen()),
  Module('Activity', 'Alerts & audit log', Icons.notifications_active_rounded, 'view:dashboard', (_) => const ActivityScreen()),
  Module('Settings', 'Restaurant profile & team', Icons.settings_rounded, 'manage:settings', (_) => const RestaurantSettingsScreen()),
];

/// Grid of every admin module the signed-in user may open.
class ManageHub extends ConsumerWidget {
  const ManageHub({super.key, this.title = 'Manage', this.exclude = const []});
  final String title;
  final List<String> exclude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).profile;
    final modules = allModules.where((m) => p?.can(m.action) == true && !exclude.contains(m.title)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.2),
        itemCount: modules.length,
        itemBuilder: (_, i) => ModuleCard(module: modules[i]),
      ),
    );
  }
}

class ModuleCard extends StatelessWidget {
  const ModuleCard({super.key, required this.module});
  final Module module;
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: module.builder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.c.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(module.icon, color: context.c.accent),
          ),
          const Spacer(),
          Text(module.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(module.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.c.muted, fontSize: 12)),
        ]),
      );
}

/// Compact list of modules (used inside the Restaurant app profile).
class ModuleList extends ConsumerWidget {
  const ModuleList({super.key, required this.titles});
  final List<String> titles;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).profile;
    final modules = allModules.where((m) => titles.contains(m.title) && p?.can(m.action) == true).toList();
    if (modules.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Tools', padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final m in modules)
            ListTile(
              leading: Icon(m.icon, color: context.c.accent),
              title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(m.subtitle),
              trailing: Icon(Icons.chevron_right_rounded, color: context.c.muted),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: m.builder)),
            ),
        ]),
      ),
    ]);
  }
}
