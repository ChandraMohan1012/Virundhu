import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the dietary preference ('veg' | 'non-veg' | 'all') per logged-in user.
/// Stored in the `user_preferences` Supabase table.
class UserPrefsService {
  static final _db = Supabase.instance.client;

  /// Returns 'veg', 'non-veg', or 'all'. Defaults to 'all' if not set.
  static Future<String> fetchPref() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return 'all';

    final rows = await _db
        .from('user_preferences')
        .select('dietary')
        .eq('user_id', userId)
        .limit(1);

    if (rows.isEmpty) return 'all';
    return (rows.first['dietary'] as String?) ?? 'all';
  }

  /// Upserts the dietary preference for the current user.
  static Future<void> savePref(String pref) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    await _db.from('user_preferences').upsert({
      'user_id': userId,
      'dietary': pref,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
