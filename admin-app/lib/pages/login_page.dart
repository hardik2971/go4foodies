import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';

/// auth/login.blade.php — brand panel (lg+) + sign-in form.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

const _brandBg = Color(0xFF0A1C18);
const _poster = 'https://images.unsplash.com/photo-1577219491135-ce391730fb2c?auto=format&fit=crop&w=1400&q=70';

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error, emailError, passwordError;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final e = email.text.trim();
    // Server rules: email required|email, password required|string|min:1.
    String? ee, pe;
    if (e.isEmpty) {
      ee = 'The email field is required.';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(e)) {
      ee = 'The email field must be a valid email address.';
    }
    if (password.text.isEmpty) pe = 'The password field is required.';
    setState(() {
      emailError = ee;
      passwordError = pe;
      error = null;
    });
    if (ee != null || pe != null) return;

    setState(() => busy = true);
    try {
      await context.read<Session>().login(e, password.text);
      if (!mounted) return;
      context.go('/dashboard');
    } on ApiError catch (err) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = err.status == 401 || err.status == 400 ? 'Invalid email or password.' : 'Cannot reach the database right now. Please try again shortly.';
        password.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = 'Cannot reach the database right now. Please try again shortly.';
        password.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.of(context).size.width >= 1024;
    return Title(
      title: 'Sign in · Go4Foodie Admin',
      color: c.accent,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (wide) const Expanded(child: _BrandPanel()),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width >= 640 ? 40 : 24, vertical: 48),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 384), child: _form(context)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.of(context).size.width >= 1024;
    return AutofillGroup(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (!wide)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: _brandBg, borderRadius: BorderRadius.circular(12)),
                child: Image.asset('assets/images/go4foodie-logo-wide-light.png', height: 32, semanticLabel: 'Go4Foodie'),
              ),
            ),
          ),
        Text('WELCOME BACK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 14 * .2, color: c.accent)),
        const SizedBox(height: 8),
        Text('Sign in to your dashboard', style: display(context, size: 30, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Manage your restaurant & team from one place.', style: TextStyle(fontSize: 14, color: c.fgMuted)),
        const SizedBox(height: 32),
        if (error != null) ...[
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.dangerSoft, borderRadius: BorderRadius.circular(8)),
              child: Text(error!, style: TextStyle(fontSize: 14, color: c.danger)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _input(context, label: 'Email', controller: email, icon: LucideIcons.mail, hint: 'you@restaurant.com', error: emailError, autofill: AutofillHints.email, keyboard: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _input(context, label: 'Password', controller: password, icon: LucideIcons.lock, hint: '••••••••', error: passwordError, autofill: AutofillHints.password, obscure: true),
        const SizedBox(height: 16),
        _SubmitButton(busy: busy, onPressed: submit),
        const SizedBox(height: 24),
        // Click the demo hint to fill the form.
        _DemoHint(onTap: () {
          setState(() {
            email.text = 'george@merchant.test';
            password.text = 'admin123';
            error = null;
            emailError = null;
            passwordError = null;
          });
        }),
      ]),
    );
  }

  Widget _input(BuildContext context,
      {required String label,
      required TextEditingController controller,
      required IconData icon,
      required String hint,
      String? error,
      String? autofill,
      TextInputType? keyboard,
      bool obscure = false}) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        autofillHints: autofill == null ? null : [autofill],
        onSubmitted: (_) => submit(),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 10), child: Icon(icon, size: 16, color: c.fgMuted)),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 16),
        ),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error, style: TextStyle(fontSize: 12, color: c.danger))),
    ]);
  }
}

/// "Demo · george@merchant.test / admin123" with a copy button that fills the sign-in form.
class _DemoHint extends StatefulWidget {
  const _DemoHint({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_DemoHint> createState() => _DemoHintState();
}

class _DemoHintState extends State<_DemoHint> {
  bool _done = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _fill() {
    widget.onTap();
    setState(() => _done = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _done = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: c.surface2, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const SizedBox(width: 28), // balances the button so the text stays centred
        Expanded(
          child: Text.rich(
            TextSpan(style: TextStyle(fontSize: 12, color: c.fgMuted), children: [
              const TextSpan(text: 'Demo · '),
              TextSpan(text: 'george@merchant.test', style: TextStyle(fontWeight: FontWeight.w500, color: c.fg)),
              const TextSpan(text: ' / admin123'),
            ]),
            textAlign: TextAlign.center,
          ),
        ),
        Tooltip(
          message: _done ? 'Filled' : 'Fill in demo credentials',
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _fill,
              borderRadius: BorderRadius.circular(6),
              hoverColor: c.accentSoft,
              child: SizedBox(
                width: 28,
                height: 28,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                  child: _done
                      ? Icon(LucideIcons.check, key: const ValueKey('done'), size: 15, color: c.success)
                      : Icon(LucideIcons.copy, key: const ValueKey('copy'), size: 15, color: c.fgMuted),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  const _SubmitButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;
  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const text = TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14);
    return Opacity(
      opacity: widget.busy ? .6 : 1,
      child: MouseRegion(
        cursor: widget.busy ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: GestureDetector(
          onTap: widget.busy ? null : widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: hover && !widget.busy ? c.accentDeep : c.accent, borderRadius: BorderRadius.circular(12)),
            child: widget.busy
                ? const Center(child: Text('Signing in…', style: text))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Sign in', style: text),
                    const SizedBox(width: 8),
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 150),
                      offset: Offset(hover ? .125 : 0, 0),
                      child: const Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Dark brand panel: poster image (the original played /images/login-bg.mp4 over it) + gradients.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) {
    final accent = context.c.accent;
    return ColoredBox(
      color: _brandBg,
      child: Stack(fit: StackFit.expand, children: [
        Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, _poster, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        // bg-gradient-to-t from-[#0a1c18] via-[#0a1c18]/70 to-[#0a1c18]/30
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [_brandBg, _brandBg.withValues(alpha: .7), _brandBg.withValues(alpha: .3)],
            ),
          ),
        ),
        // bg-gradient-to-r from-transparent to-[#0a1c18]/40
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, _brandBg.withValues(alpha: .4)]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Image.asset('assets/images/go4foodie-logo-wide-light.png', height: 64, semanticLabel: 'Go4Foodie'),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 512),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 60, child: Text('“', style: display(context, size: 60, color: accent).copyWith(height: 1))),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      'Great restaurants are run in the details — every plate, every table, every shift.',
                      style: display(context, size: 36, weight: FontWeight.w500, color: Colors.white).copyWith(height: 1.25),
                    ),
                    const SizedBox(height: 20),
                    Text('Your kitchen has the craft. This is where you run the business behind it.',
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: .7))),
                  ]),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, h) in const ['Real-time orders, POS & reservations', 'Live analytics across every outlet', 'Menu, staff & inventory in one place'].indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Text(h, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: .8))),
                ]),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}
