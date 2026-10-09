import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_select_screen.dart';
import '../features/customer/customer_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/owner/owner_shell.dart';
import '../features/restaurant/restaurant_shell.dart';
import '../features/splash/splash_screen.dart';
import 'session.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      if (!s.ready) return state.matchedLocation == '/' ? null : '/';
      final loc = state.matchedLocation;
      bool under(String root) => loc == root || loc.startsWith('$root/');
      final inApp = AppRole.values.any((r) => under(r.home));
      if (!s.signedIn && inApp) return '/welcome';
      if (s.signedIn) {
        final home = s.role!.home;
        // Keep each login inside its own app.
        if (loc == '/welcome' || loc.startsWith('/login') || loc == '/register' || loc.startsWith('/onboarding')) return home;
        if (inApp && !under(home)) return home;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const RoleSelectScreen()),
      GoRoute(
        path: '/onboarding/:role',
        builder: (_, s) => OnboardingScreen(role: AppRole.parse(s.pathParameters['role']) ?? AppRole.customer),
      ),
      GoRoute(
        path: '/login/:role',
        builder: (_, s) => LoginScreen(role: AppRole.parse(s.pathParameters['role']) ?? AppRole.customer),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/c', builder: (_, _) => const CustomerShell()),
      GoRoute(path: '/r', builder: (_, _) => const RestaurantShell()),
      GoRoute(path: '/o', builder: (_, _) => const OwnerShell()),
    ],
  );
});
