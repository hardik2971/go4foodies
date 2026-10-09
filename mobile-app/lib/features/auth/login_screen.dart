import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'role_select_screen.dart';
import 'server_settings.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});
  final AppRole role;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  String get _subtitle => switch (widget.role) {
        AppRole.customer => 'Sign in to order, book and track your visits.',
        AppRole.restaurant => 'Staff sign-in — use your admin or staff account.',
        AppRole.owner => 'Owner sign-in — full access to your restaurant.',
      };

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(widget.role, _email.text, _password.text);
      // Router redirect takes the user into their app.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'),
        ),
        actions: [IconButton(tooltip: 'Server settings', icon: const Icon(Icons.tune_rounded), onPressed: () => showServerSettings(context, ref))],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
            const Center(child: BrandLogo(height: 64)),
            const SizedBox(height: 28),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(roleIcon(widget.role), color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Eyebrow('${widget.role.label} App'),
            ]),
            const SizedBox(height: 14),
            Text('Welcome back', style: display(context, size: 32)),
            const SizedBox(height: 6),
            Text(_subtitle, style: TextStyle(color: c.muted)),
            const SizedBox(height: 28),
            TextFormField(
              key: const Key('login-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('login-password'),
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w600))),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('login-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink))
                  : const Text('Sign in'),
            ),
            if (widget.role == AppRole.customer) ...[
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('New to Go4Foodie?', style: TextStyle(color: c.muted)),
                TextButton(onPressed: () => context.push('/register'), child: const Text('Create account')),
              ]),
            ] else ...[
              const SizedBox(height: 20),
              Text(
                widget.role == AppRole.owner
                    ? 'Owner accounts are managed in the admin (Settings → Team).'
                    : 'Accounts are created by your manager in the admin (Staff).',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 12.5),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
