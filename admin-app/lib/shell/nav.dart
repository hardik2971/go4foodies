import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Sidebar (layouts/app.blade.php) — order, labels, icons and permissions.
class NavItem {
  const NavItem(this.href, this.label, this.icon, this.perm);
  final String href, label, perm;
  final IconData icon;
}

const navItems = [
  NavItem('/dashboard', 'Overview', LucideIcons.layoutGrid, 'view:dashboard'),
  NavItem('/orders', 'Orders', LucideIcons.shoppingCart, 'manage:orders'),
  NavItem('/menu', 'Menu', LucideIcons.clipboardList, 'manage:menu'),
  NavItem('/reservations', 'Reservations', LucideIcons.calendarCheck, 'manage:reservations'),
  NavItem('/tables', 'Tables', LucideIcons.qrCode, 'manage:tables'),
  NavItem('/floor', 'Floor', LucideIcons.layoutDashboard, 'manage:tables'),
  NavItem('/table-analytics', 'Table Analytics', LucideIcons.activity, 'view:reports'),
  NavItem('/staff', 'Staff', LucideIcons.users, 'manage:staff'),
  NavItem('/customers', 'Customers', LucideIcons.contact, 'manage:customers'),
  NavItem('/gift-cards', 'Gift Cards', LucideIcons.gift, 'manage:coupons'),
  NavItem('/transactions', 'Transactions', LucideIcons.creditCard, 'view:reports'),
  NavItem('/inventory', 'Inventory', LucideIcons.package, 'manage:inventory'),
  NavItem('/reports', 'Reports', LucideIcons.barChart3, 'view:reports'),
];

const auditNav = NavItem('/audit', 'Audit Log', LucideIcons.scrollText, 'manage:settings');

/// Topbar title + subtitle by path prefix (first match; /dashboard exact; fallback Overview).
const pageTitles = <(String, String, String)>[
  ('/dashboard', 'Overview', 'Manage your restaurant & team members from here.'),
  ('/orders', 'Orders', 'Track and manage every order across outlets.'),
  ('/menu', 'Menu', 'Manage dishes, categories, and availability.'),
  ('/reservations', 'Reservations', 'Table bookings & private events from your guests.'),
  ('/floor', 'Floor Plan', 'Live table status, sessions & occupancy.'),
  ('/pos', 'Point of Sale', 'Table billing, order entry & checkout.'),
  ('/tables', 'Table Management', 'QR codes for table-side ordering.'),
  ('/outlets', 'Outlets', 'Locations, managers, and operational metrics.'),
  ('/staff', 'Staff', 'Your team directory and duty status.'),
  ('/customers', 'Customers', 'Guest profiles, history, and lifetime value.'),
  ('/gift-cards', 'Gift Card & Coupon Management', 'Purchases, codes, and coupon status.'),
  ('/transactions', 'Transactions', 'Payments across orders, gift cards & tables.'),
  ('/inventory', 'Inventory', 'Stock levels and low-stock alerts.'),
  ('/table-analytics', 'Table Analytics', 'Sessions, occupancy & table performance.'),
  ('/table-history', 'Table History', 'Complete session timeline for a table.'),
  ('/reports', 'Reports', 'Analytics and exportable insights.'),
  ('/notifications', 'Notifications', 'Recent activity across the restaurant.'),
  ('/audit', 'Audit Log', 'Every POS & table action, who and when.'),
  ('/settings', 'Settings', 'Restaurant configuration and your profile.'),
];

(String, String) titleFor(String path) {
  for (final (prefix, title, sub) in pageTitles) {
    if (prefix == '/dashboard' ? path == prefix : path.startsWith(prefix)) return (title, sub);
  }
  return ('Overview', 'Manage your restaurant & team members from here.');
}

bool isActive(String path, String href) => href == '/dashboard' ? path == href : path.startsWith(href);

/// Route → permission (the `perm:` middleware). Dashboard and notifications: auth only.
String? permFor(String path) {
  const map = {
    '/orders': 'manage:orders',
    '/menu': 'manage:menu',
    '/reservations': 'manage:reservations',
    '/tables': 'manage:tables',
    '/floor': 'manage:tables',
    '/pos': 'manage:orders',
    '/table-analytics': 'view:reports',
    '/table-history': 'view:reports',
    '/staff': 'manage:staff',
    '/customers': 'manage:customers',
    '/gift-cards': 'manage:coupons',
    '/transactions': 'view:reports',
    '/inventory': 'manage:inventory',
    '/reports': 'view:reports',
    '/outlets': 'manage:outlets',
    '/audit': 'manage:settings',
    '/settings': 'manage:settings',
  };
  for (final e in map.entries) {
    if (path == e.key || path.startsWith('${e.key}/')) return e.value;
  }
  return null;
}
