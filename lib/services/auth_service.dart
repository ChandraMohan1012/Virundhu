import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  static bool get isLoggedIn => _client.auth.currentUser != null;
  static String? get userId => _client.auth.currentUser?.id;
  static String? get userEmail => _client.auth.currentUser?.email;

  /// Exposes Supabase auth state stream so widgets can react to login/logout.
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<void> signUp(
    String email,
    String password, {
    String? fullName,
    String? phone,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    if (res.user == null) throw Exception('Sign-up failed. Check your email.');

    // Persist to profiles table
    try {
      await _client.from('profiles').upsert({
        'id': res.user!.id,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> login(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Opens Google OAuth in the system browser. Listen to [authStateChanges]
  /// to detect when sign-in completes.
  static Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.virundhu://login-callback/',
    );
  }

  static Future<void> logout() async {
    await _client.auth.signOut();
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final meta = user.userMetadata ?? const <String, dynamic>{};
    if (_hasAdminAccess(meta)) return true;

    try {
      final row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      if (row is Map<String, dynamic>) {
        return _hasAdminAccess(row);
      }
    } catch (_) {}

    return false;
  }

  static bool _hasAdminAccess(Map<String, dynamic> source) {
    return _isTruthy(source['is_admin']) ||
        _isTruthy(source['admin']) ||
        _isAdminRole(source['role']);
  }

  static bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static bool _isAdminRole(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'admin' ||
        normalized == 'super_admin' ||
        normalized == 'superadmin' ||
        normalized == 'owner' ||
        normalized == 'manager';
  }
}
