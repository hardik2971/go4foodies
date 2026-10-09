import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/profile_screen.dart';
import 'bookings_screen.dart';
import 'checkout_screen.dart';
import 'customer_providers.dart';
import 'gift_cards_screen.dart';
import 'menu_screen.dart';
import 'orders_screen.dart';
import 'table_scan_screen.dart';

final customerTabProvider = StateProvider<int>((_) => 0);

class CustomerShell extends ConsumerWidget {
  const CustomerShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(customerTabProvider);
    final cart = ref.watch(cartProvider);
    const pages = [CustomerHome(), MenuScreen(), MyOrdersScreen(), BookingsScreen(), ProfileScreen()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!cart.isEmpty && tab <= 1) const _CartBar(),
        NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => ref.read(customerTabProvider.notifier).state = i,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu_rounded), label: 'Menu'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
            NavigationDestination(icon: Icon(Icons.event_seat_outlined), selectedIcon: Icon(Icons.event_seat_rounded), label: 'Bookings'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ]),
    );
  }
}

class _CartBar extends ConsumerWidget {
  const _CartBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Container(
      color: context.c.bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: AppColors.goldBrand,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: const Key('cart-bar'),
          borderRadius: BorderRadius.circular(999),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                child: Text('${cart.count}', style: const TextStyle(color: AppColors.goldBrand, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Text(cart.table != null ? 'Table ${cart.table!.number} · View order' : 'View cart',
                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(money(cart.total), style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
        ),
      ),
    );
  }
}

class CustomerHome extends ConsumerWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final home = ref.watch(customerHomeProvider);
    final menu = ref.watch(menuProvider);
    void goTab(int i) => ref.read(customerTabProvider.notifier).state = i;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return RefreshIndicator(
      color: context.c.accent,
      onRefresh: () async {
        ref.invalidate(customerHomeProvider);
        ref.invalidate(menuProvider);
        await ref.read(customerHomeProvider.future);
      },
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _Hero(greeting: greeting, name: profile?.name.split(' ').first ?? '')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Row(children: [
              Expanded(child: _QuickAction(icon: Icons.shopping_bag_rounded, label: 'Take away', onTap: () => goTab(1))),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  key: const Key('scan-table'),
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Order at table',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TableScanScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.event_available_rounded, label: 'Book a table', onTap: () => openReservationForm(context))),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Gift cards',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GiftCardsScreen())),
                ),
              ),
            ]),
          ),
        ),
        // Live order + upcoming booking cards.
        SliverToBoxAdapter(
          child: home.when(
            data: (h) {
              final active = ((h['activeOrders'] as List?) ?? const []).cast<Json>();
              final upcoming = ((h['upcomingReservations'] as List?) ?? const []).cast<Json>();
              if (active.isEmpty && upcoming.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (active.isNotEmpty) ...[
                  const SectionTitle('Live orders'),
                  for (final o in active)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: OrderTile(order: o),
                    ),
                ],
                if (upcoming.isNotEmpty) ...[
                  SectionTitle('Upcoming bookings', action: 'All', onAction: () => goTab(3)),
                  for (final r in upcoming)
                    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: ReservationTile(reservation: r)),
                ],
              ]);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
        SliverToBoxAdapter(child: SectionTitle("Chef's picks", action: 'Full menu', onAction: () => goTab(1))),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 250,
            child: menu.when(
              data: (m) {
                final picks = [...m.items]..sort((a, b) => b.rating.compareTo(a.rating));
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: picks.take(8).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _PickCard(item: picks[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(menuProvider)),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: home.maybeWhen(
            data: (h) => _VisitCard(profile: (h['profile'] as Json?) ?? const {}),
            orElse: () => const _VisitCard(profile: {}),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.greeting, required this.name});
  final String greeting, name;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/food_pizza.jpg', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0x880A1C18), context.c.bg],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const BrandLogo(height: 40, forceLight: true),
              const Spacer(),
              Eyebrow(greeting, color: AppColors.goldSoft),
              const SizedBox(height: 6),
              Text(name.isEmpty ? 'Welcome' : 'Welcome, $name', style: display(context, size: 30)),
              const SizedBox(height: 4),
              Text('Seasonal plates, curated wine, and a table waiting for you.', style: TextStyle(color: context.c.muted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(children: [
          Icon(icon, color: context.c.accent, size: 26),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _PickCard extends ConsumerWidget {
  const _PickCard({required this.item});
  final MenuItem item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 180,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => showMenuItemSheet(context, item),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NetImage(item.imageUrl, height: 130, width: 180, radius: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(item.category, style: TextStyle(color: context.c.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Text(money(item.price), style: TextStyle(color: context.c.accent, fontWeight: FontWeight.w800)),
                const Spacer(),
                Icon(Icons.star_rounded, size: 16, color: context.c.gold),
                Text(item.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.profile});
  final Json profile;
  @override
  Widget build(BuildContext context) {
    final address = (profile['address'] as String?)?.isNotEmpty == true ? profile['address'] as String : '245 Harbor View Avenue, Boston, MA 02127';
    final phone = (profile['phone'] as String?)?.isNotEmpty == true ? profile['phone'] as String : '+1 617 482 6060';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Visit us'),
          const SizedBox(height: 10),
          Text(profile['name'] as String? ?? 'Go4Foodie', style: display(context, size: 20)),
          const SizedBox(height: 12),
          _line(context, Icons.place_outlined, address),
          _line(context, Icons.call_outlined, phone),
          _line(context, Icons.schedule_rounded, 'Mon–Fri 11:30am–11pm · Sat noon–11pm'),
        ]),
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: context.c.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: context.c.muted))),
        ]),
      );
}
