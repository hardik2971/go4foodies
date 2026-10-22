import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';

/// The signed-in admin user (port of CurrentUser + the layout's attention badge).
class AdminUser {
  AdminUser.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = (j['name'] ?? '') as String,
        email = (j['email'] ?? '') as String,
        role = j['role'] as String?,
        permissions = List<String>.from(j['permissions'] ?? const []);

  final String id, name, email;
  final String? role;
  final List<String> permissions;

  bool can(String action) => permissions.contains(action);

  /// Topbar role label: OWNER→Owner, MANAGER→Manager, STAFF→Staff (else raw).
  String get roleLabel => const {'OWNER': 'Owner', 'MANAGER': 'Manager', 'STAFF': 'Staff'}[role] ?? (role ?? '');

  String get initials => initialsOf(name);
}

/// First letters of the first two words (bizInitials).
String initialsOf(String name) =>
    name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

class Session extends ChangeNotifier {
  AdminUser? user;
  int attentionCount = 0;
  bool ready = false;

  bool can(String action) => user?.can(action) ?? false;

  /// Restore a persisted Firebase Auth session ("remember me" was always on).
  Future<void> restore() async {
    try {
      final fb = await FirebaseAuth.instance.authStateChanges().first;
      if (fb != null) await refresh();
    } catch (_) {
      user = null;
    }
    ready = true;
    notifyListeners();
  }

  /// Re-reads /me — user, permissions and the bell badge (the layout recomputed it on every page).
  Future<void> refresh() async {
    try {
      final me = await Api.get('/me');
      user = AdminUser.fromJson(Map<String, dynamic>.from(me['user']));
      attentionCount = (me['attentionCount'] as num?)?.toInt() ?? 0;
    } on ApiError catch (e) {
      if (e.status == 401) {
        await FirebaseAuth.instance.signOut();
        user = null;
      }
    }
    notifyListeners();
  }

  /// POST /api/admin/auth/login → Firebase custom token → Firebase Auth session.
  Future<void> login(String email, String password) async {
    final res = await Api.post('/auth/login', {'email': email, 'password': password});
    await FirebaseAuth.instance.signInWithCustomToken(res['token'] as String);
    user = AdminUser.fromJson(Map<String, dynamic>.from(res['user']));
    await refresh();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    user = null;
    attentionCount = 0;
    notifyListeners();
  }
}
