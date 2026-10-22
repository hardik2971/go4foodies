import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

/// Motion system: page fade-through, cascading reveals, skeleton shimmer, count-up numbers,
/// press feedback. Everything is skipped when the OS asks for reduced motion.

const kEaseOut = Cubic(0.22, 1, 0.36, 1); // "easeOutQuint"-like: fast start, soft landing

bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ---------------------------------------------------------------- page transition

/// Fade-through: the incoming page (on an opaque backdrop, so the old page never ghosts through)
/// fades in while rising 10px and settling from 99% scale.
CustomTransitionPage<void> fadeThroughPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.uri.path,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      child: child,
      transitionsBuilder: (context, animation, secondary, child) {
        if (reduceMotion(context)) return child;
        final fade = CurvedAnimation(parent: animation, curve: const Interval(0, .7, curve: Curves.easeOut));
        final move = CurvedAnimation(parent: animation, curve: kEaseOut);
        return ColoredBox(
          color: context.c.bg,
          child: FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: move,
              child: child,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, 10 * (1 - move.value)),
                child: Transform.scale(scale: .99 + .01 * move.value, child: child),
              ),
            ),
          ),
        );
      },
    );

// ---------------------------------------------------------------- cascading reveal

/// Fades + lifts its child in once, on first mount. The delay grows with the widget's position on
/// screen (top-left first), so a page of cards cascades in without any index bookkeeping.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.distance = 14});
  final Widget child;
  final double distance;
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: kEaseOut);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reduceMotion(context)) {
        _c.value = 1;
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      final pos = box != null && box.hasSize ? box.localToGlobal(Offset.zero) : Offset.zero;
      final ms = ((pos.dy - 80).clamp(0, 900) / 900 * 280 + (pos.dx.clamp(0, 1600) / 1600) * 90).round();
      _timer = Timer(Duration(milliseconds: ms), () {
        if (mounted) _c.forward();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(offset: Offset(0, widget.distance * (1 - _t.value)), child: child),
        ),
      );
}

// ---------------------------------------------------------------- count-up numbers

final _numberRe = RegExp(r'^(\D*?)(-?\d[\d,]*(?:\.\d+)?)(.*)$');

/// Animates the numeric part of [text] from 0 on first build ("$15,750" → counts up, keeps
/// grouping/decimals/prefix/suffix). Non-numeric text is shown as-is. Later changes jump directly.
class CountUpText extends StatefulWidget {
  const CountUpText(this.text, {super.key, this.style, this.duration = const Duration(milliseconds: 900)});
  final String text;
  final TextStyle? style;
  final Duration duration;
  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void didUpdateWidget(CountUpText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _c.value = 1; // data refresh: no replay
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _numberRe.firstMatch(widget.text);
    if (m == null) return Text(widget.text, style: widget.style, overflow: TextOverflow.ellipsis);
    final raw = m.group(2)!;
    final target = double.tryParse(raw.replaceAll(',', '')) ?? 0;
    final decimals = raw.contains('.') ? raw.split('.').last.length : 0;
    final grouping = raw.contains(',');
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final v = target * _t.value;
        var s = v.toStringAsFixed(decimals);
        if (grouping) {
          final parts = s.split('.');
          final neg = parts[0].startsWith('-');
          final digits = neg ? parts[0].substring(1) : parts[0];
          final g = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
          s = '${neg ? '-' : ''}$g${parts.length > 1 ? '.${parts[1]}' : ''}';
        }
        return Text('${m.group(1)}$s${m.group(3)}', style: widget.style, overflow: TextOverflow.ellipsis);
      },
    );
  }
}

// ---------------------------------------------------------------- skeleton shimmer

/// Soft diagonal shimmer sweeping across [child] (skeleton placeholders).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    // A translucent highlight band sweeps over the skeleton (srcATop: only where something is painted,
    // and transparent stops leave the bones untouched).
    final glow = Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: .07) : Colors.white.withValues(alpha: .75);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final x = -1.5 + 3.0 * _c.value;
          return LinearGradient(
            begin: Alignment(x - 1, -.3),
            end: Alignment(x + 1, .3),
            // Edges are the glow colour at 0 alpha (not Colors.transparent = black), so the band
            // never interpolates through grey.
            colors: [glow.withValues(alpha: 0), glow, glow.withValues(alpha: 0)],
            stops: const [.4, .5, .6],
          ).createShader(rect);
        },
        child: child,
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({this.width, this.height = 12, this.radius = 6});
  final double? width;
  final double height, radius;
  @override
  Widget build(BuildContext context) => Container(
      width: width, height: height, decoration: BoxDecoration(color: context.c.border.withValues(alpha: .75), borderRadius: BorderRadius.circular(radius)));
}

/// Page-shaped placeholder: a row of stat tiles and a content card, shimmering.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget card({required Widget child, double? height}) => Container(
          height: height,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(radiusCard), border: Border.all(color: c.border)),
          child: child,
        );
    return Shimmer(
      child: LayoutBuilder(builder: (context, box) {
        final cols = (box.maxWidth / 220).floor().clamp(1, 4);
        final w = (box.maxWidth - 16 * (cols - 1)) / cols;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 16, runSpacing: 16, children: [
            for (var i = 0; i < cols; i++)
              SizedBox(
                width: w,
                child: card(
                  child: Row(children: [
                    const _Bone(width: 40, height: 40, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Bone(width: w * .35), const SizedBox(height: 10), _Bone(width: w * .5, height: 18)])),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Bone(width: 180, height: 16),
              const SizedBox(height: 22),
              for (var i = 0; i < 7; i++) ...[
                Row(children: [
                  const _Bone(width: 36, height: 36, radius: 18),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: _Bone(height: 12, width: math.max(80, box.maxWidth * (.18 + (i % 3) * .05)))),
                  const SizedBox(width: 24),
                  const Expanded(flex: 2, child: _Bone(height: 12)),
                  const SizedBox(width: 24),
                  const Expanded(child: _Bone(height: 12)),
                ]),
                if (i < 6) const SizedBox(height: 20),
              ],
            ]),
          ),
        ]);
      }),
    );
  }
}

// ---------------------------------------------------------------- press feedback

/// Scales its child to 97% while pressed (buttons, tappable cards).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Lifts a tappable surface on hover (translate -2px + stronger shadow).
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, required this.radius, this.enabled = true});
  final Widget child;
  final double radius;
  final bool enabled;
  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final c = context.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius), boxShadow: _hover ? c.popShadow : const []),
        child: widget.child,
      ),
    );
  }
}
