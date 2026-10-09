import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'server_settings.dart';

IconData roleIcon(AppRole r) => switch (r) {
  AppRole.customer => Icons.restaurant_menu_rounded,
  AppRole.restaurant => Icons.room_service_rounded,
  AppRole.owner => Icons.insights_rounded,
};

/// Entry point for signed-out users: choose one of the three logins.
class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.read(prefsProvider);
    final last = AppRole.parse(prefs.getString('lastRole'));

    void pick(AppRole r) => context.push(prefs.seenOnboarding(r) ? '/login/${r.name}' : '/onboarding/${r.name}');

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/food_grill.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x990A1C18), Color(0xE60A1C18), AppColors.ink],
                stops: [0, 0.45, 0.75],
              ),
            ),
          ),
          SafeArea(
            // Scrolls on short screens; on tall ones the Spacer pushes content down.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            tooltip: 'Server settings',
                            icon: const Icon(Icons.tune_rounded, color: AppColors.cream),
                            onPressed: () => showServerSettings(context, ref),
                          ),
                        ),
                        const Spacer(),
                        const Center(child: BrandLogo(height: 92, forceLight: true)),
                        const SizedBox(height: 22),
                        const Center(child: GoldDivider(width: 64)),
                        const SizedBox(height: 22),
                        Text(
                          'Great moments with\ngreat tastes',
                          textAlign: TextAlign.center,
                          style: display(context, size: 30, color: AppColors.cream),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Choose how you would like to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFA9BCB5)),
                        ),
                        const SizedBox(height: 26),
                        for (final r in AppRole.values) ...[_RoleCard(role: r, recent: r == last, onTap: () => pick(r)), const SizedBox(height: 12)],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onTap, this.recent = false});
  final AppRole role;
  final VoidCallback onTap;
  final bool recent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC0F2621),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: recent ? AppColors.goldBrand : const Color(0xFF2A4A40)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('role-${role.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [AppColors.goldSoft, AppColors.goldDeep]),
                ),
                child: Icon(roleIcon(role), color: AppColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${role.label} App', style: display(context, size: 18, color: AppColors.cream)),
                        if (recent) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'LAST USED',
                            style: TextStyle(color: AppColors.goldBrand, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(role.tagline, style: const TextStyle(color: Color(0xFFA9BCB5), fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.goldBrand),
            ],
          ),
        ),
      ),
    );
  }
}
