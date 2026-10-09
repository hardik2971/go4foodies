import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// The three apps in one: which login the user chose.
enum AppRole {
  customer('Customer', 'Order, book a table and track your visit'),
  restaurant('Restaurant', 'Run the floor, kitchen orders and POS'),
  owner('Owner', 'Business insights and full control');

  const AppRole(this.label, this.tagline);
  final String label;
  final String tagline;

  String get home => switch (this) {
        AppRole.customer => '/c',
        AppRole.restaurant => '/r',
        AppRole.owner => '/o',
      };

  static AppRole? parse(String? v) => AppRole.values.where((r) => r.name == v).firstOrNull;
}

/// Signed-in profile as returned by /api/mobile/auth/login|me.
class Profile {
  Profile(this.raw);
  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  String get name => (raw['name'] as String?) ?? '';
  String get email => (raw['email'] as String?) ?? '';
  String get phone => (raw['phone'] as String?) ?? '';
  String get address => (raw['address'] as String?) ?? '';
  String get kind => (raw['kind'] as String?) ?? 'customer';
  String? get role => raw['role'] as String?;
  String get title => (raw['title'] as String?) ?? role ?? 'Guest';
  String? get dutyStatus => raw['dutyStatus'] as String?;
  List<String> get permissions => ((raw['permissions'] as List?) ?? const []).cast<String>();
  bool can(String action) => permissions.contains(action);
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class SessionState {
  const SessionState({this.token, this.role, this.profile, this.ready = false});
  final String? token;
  final AppRole? role;
  final Profile? profile;
  final bool ready;
  bool get signedIn => token != null && profile != null && role != null;
}

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('overridden in main'));

final apiProvider = Provider<Api>((ref) {
  final prefs = ref.watch(prefsProvider);
  return Api(prefs.getString('baseUrl') ?? kDefaultBaseUrl);
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final v = ref.watch(prefsProvider).getString('themeMode');
  return v == 'light' ? ThemeMode.light : ThemeMode.dark;
});

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  static const _storage = FlutterSecureStorage();

  Api get _api => ref.read(apiProvider);
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  SessionState build() {
    _api.onUnauthorized = () => signOut();
    return const SessionState();
  }

  /// Restore a saved session at launch; validates the token against /me.
  Future<void> restore() async {
    final token = await _storage.read(key: 'token');
    final role = AppRole.parse(await _storage.read(key: 'role'));
    final cached = await _storage.read(key: 'profile');
    if (token == null || role == null || cached == null) {
      state = const SessionState(ready: true);
      return;
    }
    _api.token = token;
    var profile = Profile(jsonDecode(cached) as Map<String, dynamic>);
    try {
      final res = await _api.get('/api/mobile/auth/me');
      profile = Profile(res['user'] as Map<String, dynamic>);
      await _storage.write(key: 'profile', value: jsonEncode(profile.raw));
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await _clear();
        state = SessionState(role: role, ready: true);
        return;
      }
      // Offline / server down: keep the cached profile, screens will retry.
    }
    state = SessionState(token: token, role: role, profile: profile, ready: true);
  }

  Future<void> signIn(AppRole role, String email, String password) async {
    final res = await _api.post('/api/mobile/auth/login', {'email': email.trim(), 'password': password, 'app': role.name});
    await _accept(role, res);
  }

  Future<void> register({required String name, required String email, required String phone, required String password}) async {
    final res = await _api.post('/api/mobile/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
    });
    await _accept(AppRole.customer, res);
  }

  Future<void> _accept(AppRole role, Map<String, dynamic> res) async {
    final token = res['token'] as String;
    final profile = Profile(res['user'] as Map<String, dynamic>);
    _api.token = token;
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'role', value: role.name);
    await _storage.write(key: 'profile', value: jsonEncode(profile.raw));
    await _prefs.setString('lastRole', role.name);
    state = SessionState(token: token, role: role, profile: profile, ready: true);
  }

  void updateProfile(Map<String, dynamic> raw) {
    final p = Profile(raw);
    _storage.write(key: 'profile', value: jsonEncode(raw));
    state = SessionState(token: state.token, role: state.role, profile: p, ready: true);
  }

  Future<void> refreshProfile() async {
    final res = await _api.get('/api/mobile/auth/me');
    updateProfile(res['user'] as Map<String, dynamic>);
  }

  Future<void> signOut() async {
    final role = state.role;
    await _clear();
    state = SessionState(role: role, ready: true);
  }

  Future<void> _clear() async {
    _api.token = null;
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'profile');
  }
}

/// Onboarding is shown once per login type.
extension OnboardingPrefs on SharedPreferences {
  bool seenOnboarding(AppRole r) => getBool('onboarded_${r.name}') ?? false;
  Future<void> markOnboarded(AppRole r) => setBool('onboarded_${r.name}', true);
}
