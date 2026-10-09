import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/session.dart';
import '../../core/theme.dart';

class _Slide {
  const _Slide(this.image, this.icon, this.eyebrow, this.title, this.body, this.points);
  final String image;
  final IconData icon;
  final String eyebrow, title, body;
  final List<String> points;
}

/// Each login type gets its own overview of what its app does.
const _slides = <AppRole, List<_Slide>>{
  AppRole.customer: [
    _Slide('assets/images/food_grill.jpg', Icons.restaurant_menu_rounded, 'Our menu',
        'Seasonal plates,\none tap away', 'Browse the live menu exactly as our kitchen serves it today.', ['Live prices & availability', 'Search by category', 'Chef favourites tagged']),
    _Slide('assets/images/food_pizza.jpg', Icons.shopping_bag_rounded, 'Order your way',
        'Take away or\norder at your table', 'Schedule a pickup, or scan the QR on your table and send it straight to the kitchen.', ['Pickup now or later', 'Scan table QR to order', 'Track every order live']),
    _Slide('assets/images/food_salad.jpg', Icons.event_seat_rounded, 'Reserve',
        'A table waiting\nfor you', 'Book a table or plan a private event, and keep gift cards in one place.', ['Real-time table availability', 'Private events & buyouts', 'Gift cards & coupons']),
  ],
  AppRole.restaurant: [
    _Slide('assets/images/food_pizza.jpg', Icons.table_restaurant_rounded, 'Live floor',
        'Every table,\nat a glance', 'See which tables are free, occupied, reserved or waiting to pay — updated live.', ['Open tables & seat guests', 'Assign waiters', 'Cleaning & service states']),
    _Slide('assets/images/food_grill.jpg', Icons.point_of_sale_rounded, 'Point of sale',
        'Take orders,\nsettle the bill', 'Add dishes, send KOTs, split payments and close the table from your phone.', ['Add / void items', 'Discount, tax, service & tip', 'Split & partial payments']),
    _Slide('assets/images/food_salad.jpg', Icons.receipt_long_rounded, 'Service',
        'Kitchen orders\n& bookings', 'Move orders from pending to ready, and manage tonight’s reservations.', ['Kitchen order board', 'Reservation check-in', 'Menu availability & stock']),
  ],
  AppRole.owner: [
    _Slide('assets/images/food_salad.jpg', Icons.insights_rounded, 'Insights',
        'Your restaurant,\nin numbers', 'Revenue, orders, peak hours and best sellers — live from the same data as the admin.', ['Dashboard KPIs', 'Sales & payment mix', 'Table performance']),
    _Slide('assets/images/food_grill.jpg', Icons.tune_rounded, 'Full control',
        'Manage everything\non the go', 'Menu, staff, customers, gift cards, tables and inventory, wherever you are.', ['Menu & pricing', 'Staff & duty status', 'Customers & gift cards']),
    _Slide('assets/images/food_pizza.jpg', Icons.verified_user_rounded, 'Oversight',
        'Every action,\naccounted for', 'Audit trail, transactions and alerts keep you informed of what happens on the floor.', ['Audit log', 'Transactions feed', 'Restaurant settings']),
  ],
};

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.role});
  final AppRole role;
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  List<_Slide> get slides => _slides[widget.role]!;

  Future<void> _finish() async {
    await ref.read(prefsProvider).markOnboarded(widget.role);
    if (mounted) context.pushReplacement('/login/${widget.role.name}');
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(children: [
        PageView.builder(
          controller: _page,
          itemCount: slides.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => _SlideView(slide: slides[i]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.cream), onPressed: () => context.pop()),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x55000000), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x55F5761E))),
                child: Text('${widget.role.label} App', style: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
              const Spacer(),
              if (!last) TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(color: AppColors.cream))),
            ]),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: SafeArea(
            top: false,
            child: Row(children: [
              SmoothPageIndicator(
                controller: _page,
                count: slides.length,
                effect: const ExpandingDotsEffect(dotHeight: 8, dotWidth: 8, activeDotColor: AppColors.goldBrand, dotColor: Color(0xFF35554B)),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('onboarding-next'),
                onPressed: last ? _finish : () => _page.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic),
                style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Image.asset(slide.image, fit: BoxFit.cover),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x330A1C18), Color(0xCC0A1C18), AppColors.ink],
            stops: [0, 0.42, 0.62],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 120),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.goldSoft, AppColors.goldDeep])),
            child: Icon(slide.icon, color: AppColors.ink, size: 28),
          ),
          const SizedBox(height: 20),
          Text(slide.eyebrow.toUpperCase(), style: const TextStyle(color: AppColors.goldBrand, letterSpacing: 2.6, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 10),
          Text(slide.title, style: display(context, size: 34, color: AppColors.cream)),
          const SizedBox(height: 12),
          Text(slide.body, style: const TextStyle(color: Color(0xFFC5D3CE), fontSize: 15, height: 1.45)),
          const SizedBox(height: 18),
          for (final p in slide.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.goldBrand),
                const SizedBox(width: 10),
                Text(p, style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
