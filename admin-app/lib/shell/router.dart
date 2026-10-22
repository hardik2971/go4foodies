import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import '../widgets/motion.dart';
import '../pages/login_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/orders_page.dart';
import '../pages/menu_page.dart';
import '../pages/reservations_page.dart';
import '../pages/tables_page.dart';
import '../pages/floor_page.dart';
import '../pages/pos_page.dart';
import '../pages/table_analytics_page.dart';
import '../pages/table_history_page.dart';
import '../pages/staff_page.dart';
import '../pages/customers_page.dart';
import '../pages/gift_cards_page.dart';
import '../pages/transactions_page.dart';
import '../pages/inventory_page.dart';
import '../pages/reports_page.dart';
import '../pages/outlets_page.dart';
import '../pages/notifications_page.dart';
import '../pages/audit_page.dart';
import '../pages/settings_page.dart';
import 'app_shell.dart';
import 'nav.dart';

int _days(GoRouterState s, int def) {
  final d = int.tryParse(s.uri.queryParameters['days'] ?? '');
  return [1, 7, 30].contains(d) ? d! : def;
}

GoRouter buildRouter(Session session) => GoRouter(
      refreshListenable: session,
      redirect: (context, state) {
        if (!session.ready) return null;
        final path = state.uri.path;
        final signedIn = session.user != null;
        if (!signedIn) return path == '/login' ? null : '/login';
        if (path == '/login' || path == '/') return '/dashboard';
        // `perm:` middleware: no permission → dashboard with flash error.
        final perm = permFor(path);
        if (perm != null && !session.can(perm)) {
          WidgetsBinding.instance.addPostFrameCallback((_) => toast('You do not have permission for that page.', error: true));
          return '/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/dashboard'),
        GoRoute(path: '/login', pageBuilder: (_, s) => fadeThroughPage(s, const LoginPage())),
        ShellRoute(
          builder: (context, state, child) => AppShell(path: state.uri.path, child: child),
          routes: [
            _page('/dashboard', (_) => const DashboardPage()),
            _page('/orders', (_) => const OrdersPage()),
            _page('/menu', (_) => const MenuPage()),
            _page('/reservations', (_) => const ReservationsPage()),
            _page('/tables', (_) => const TablesPage()),
            _page('/floor', (_) => const FloorPage()),
            _page('/pos/:tableId', (s) => PosPage(tableId: s.pathParameters['tableId']!)),
            _page('/table-analytics', (s) => TableAnalyticsPage(days: _days(s, 1))),
            _page('/table-history/:tableId', (s) => TableHistoryPage(tableId: s.pathParameters['tableId']!, days: _days(s, 30))),
            _page('/staff', (_) => const StaffPage()),
            _page('/customers', (_) => const CustomersPage()),
            _page('/gift-cards', (_) => const GiftCardsPage()),
            _page('/transactions', (_) => const TransactionsPage()),
            _page('/inventory', (_) => const InventoryPage()),
            _page('/reports', (_) => const ReportsPage()),
            _page('/outlets', (_) => const OutletsPage()),
            _page('/notifications', (_) => const NotificationsPage()),
            _page('/audit', (_) => const AuditPage()),
            _page('/settings', (_) => const SettingsPage()),
          ],
        ),
      ],
    );

/// A shell page: its own scroll view (fresh scroll position per page) + the fade-through transition.
/// The page key includes the query (e.g. ?days=7) so period tabs animate too.
GoRoute _page(String path, Widget Function(GoRouterState s) build) => GoRoute(
      path: path,
      pageBuilder: (context, s) => fadeThroughPage(
        s,
        SingleChildScrollView(
          key: ValueKey(s.uri.toString()),
          padding: const EdgeInsets.all(24),
          child: build(s),
        ),
      ),
    );
