import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/theme.dart';

/// Animated brand splash on white: faint food icons drift in the background
/// while the Go4Foodie logo blooms in (glow → pop → shimmer),
/// as the saved session is restored. Then → the role's app, or the role picker.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  /// One-shot intro timeline.
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..forward();

  /// Continuous loop for the icon drift and glow breathing.
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _boot();
  }

  Future<void> _boot() async {
    await Future.wait([
      ref.read(sessionProvider.notifier).restore(),
      Future<void>.delayed(const Duration(milliseconds: 4200)),
    ]);
    if (!mounted) return;
    final s = ref.read(sessionProvider);
    context.go(s.signedIn ? s.role!.home : '/welcome');
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Animation<double> _phase(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final glow = _phase(0.0, 0.45);
    final pop = _phase(0.08, 0.6, Curves.easeOutBack);
    final fade = _phase(0.08, 0.4);
    final shimmer = _phase(0.58, 0.95, Curves.easeInOut);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(fit: StackFit.expand, children: [
          _FoodIconField(intro: _intro, loop: _loop),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(alignment: Alignment.center, children: [
                  // Soft brand glow that blooms, then gently breathes.
                  AnimatedBuilder(
                    animation: Listenable.merge([glow, _loop]),
                    builder: (_, _) {
                      final breathe = 1 + 0.04 * math.sin(_loop.value * 2 * math.pi);
                      return Opacity(
                        opacity: glow.value,
                        child: Transform.scale(
                          scale: (0.6 + 0.4 * glow.value) * breathe,
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                AppColors.goldBrand.withValues(alpha: 0.16),
                                AppColors.brandGreen.withValues(alpha: 0.06),
                                Colors.white.withValues(alpha: 0),
                              ], stops: const [0, 0.55, 1]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Logo: pop in with a slight turn, then a light shimmer sweep.
                  AnimatedBuilder(
                    animation: Listenable.merge([pop, fade, shimmer]),
                    builder: (_, child) => Opacity(
                      opacity: fade.value,
                      child: Transform.rotate(
                        angle: -0.08 * (1 - pop.value),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * pop.value,
                          child: ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (rect) {
                              final x = -1.5 + 3.0 * shimmer.value;
                              return LinearGradient(
                                begin: Alignment(x - 0.6, -1),
                                end: Alignment(x + 0.6, 1),
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: shimmer.value > 0 && shimmer.value < 1 ? 0.55 : 0),
                                  Colors.white.withValues(alpha: 0),
                                ],
                                stops: const [0.35, 0.5, 0.65],
                              ).createShader(rect);
                            },
                            child: child,
                          ),
                        ),
                      ),
                    ),
                    child: Image.asset('assets/images/go4foodie_logo.png', height: 200),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Faint food icons scattered over a jittered grid (centre kept clear for the
/// logo). They fade in one by one and drift slowly.
class _FoodIconField extends StatelessWidget {
  const _FoodIconField({required this.intro, required this.loop});
  final Animation<double> intro;
  final Animation<double> loop;

  static const _icons = [
    Icons.local_pizza_rounded,
    Icons.lunch_dining_rounded,
    Icons.ramen_dining_rounded,
    Icons.icecream_rounded,
    Icons.local_cafe_rounded,
    Icons.bakery_dining_rounded,
    Icons.cake_rounded,
    Icons.set_meal_rounded,
    Icons.egg_alt_rounded,
    Icons.kebab_dining_rounded,
    Icons.rice_bowl_rounded,
    Icons.wine_bar_rounded,
    Icons.local_dining_rounded,
    Icons.soup_kitchen_rounded,
    Icons.fastfood_rounded,
    Icons.emoji_food_beverage_rounded,
    Icons.tapas_rounded,
    Icons.dinner_dining_rounded,
  ];

  static final List<_Spot> _spots = _layout();

  static List<_Spot> _layout() {
    final rnd = math.Random(4);
    const cols = 4, rows = 8;
    final spots = <_Spot>[];
    var i = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Cell centre in 0..1, plus jitter within the cell.
        final x = (c + 0.5 + (rnd.nextDouble() - 0.5) * 0.7) / cols;
        final y = (r + 0.5 + (rnd.nextDouble() - 0.5) * 0.7) / rows;
        // Keep the logo area clear.
        if ((x - 0.5).abs() < 0.3 && (y - 0.48).abs() < 0.2) continue;
        spots.add(_Spot(
          x: x,
          y: y,
          icon: _icons[i % _icons.length],
          size: 20 + rnd.nextDouble() * 16,
          angle: (rnd.nextDouble() - 0.5) * 0.9,
          phase: rnd.nextDouble() * 2 * math.pi,
          green: i.isOdd,
          delay: rnd.nextDouble() * 0.5,
        ));
        i++;
      }
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return AnimatedBuilder(
        animation: Listenable.merge([intro, loop]),
        builder: (_, _) => Stack(children: [
          for (final s in _spots) _buildIcon(s, box),
        ]),
      );
    });
  }

  Widget _buildIcon(_Spot s, BoxConstraints box) {
    final t = ((intro.value - s.delay) / 0.35).clamp(0.0, 1.0);
    final appear = Curves.easeOut.transform(t);
    final wave = loop.value * 2 * math.pi + s.phase;
    return Positioned(
      left: s.x * box.maxWidth - s.size / 2 + 4 * math.cos(wave),
      top: s.y * box.maxHeight - s.size / 2 + 6 * math.sin(wave) + 12 * (1 - appear),
      child: Opacity(
        opacity: 0.08 * appear,
        child: Transform.rotate(
          angle: s.angle,
          child: Icon(s.icon, size: s.size, color: s.green ? AppColors.brandGreen : AppColors.goldDeep),
        ),
      ),
    );
  }
}

class _Spot {
  const _Spot({
    required this.x,
    required this.y,
    required this.icon,
    required this.size,
    required this.angle,
    required this.phase,
    required this.green,
    required this.delay,
  });
  final double x, y, size, angle, phase, delay;
  final IconData icon;
  final bool green;
}
