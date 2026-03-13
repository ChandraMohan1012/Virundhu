import 'package:supabase_flutter/supabase_flutter.dart';

class MenuService {
  static final _db = Supabase.instance.client;

  /// Fetch all active menu items. Each row has:
  /// id, name, image_url, price (int), category, tags (text[]), is_trending, is_available
  static Future<List<Map<String, dynamic>>> fetchMenu() async {
    final rows = await _db
        .from('menu_items')
        .select()
        .neq('is_available', false) // include true AND null rows
        .order('category')
        .order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch only trending items (shown on home dashboard).
  static Future<List<Map<String, dynamic>>> fetchTrending() async {
    final rows = await _db
        .from('menu_items')
        .select()
        .neq('is_available', false) // include true AND null rows
        .eq('is_trending', true)
        .order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> fetchAllMenuAdmin() async {
    final rows = await _db
        .from('menu_items')
        .select()
        .order('category')
        .order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> saveMenuItem({
    Object? id,
    required String name,
    required int price,
    required String category,
    String? imageUrl,
    List<String>? tags,
    bool isAvailable = true,
    bool isTrending = false,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'price': price,
      'category': category,
      'image_url': imageUrl,
      'tags': tags ?? <String>[],
      'is_available': isAvailable,
      'is_trending': isTrending,
    };

    if (id == null) {
      await _db.from('menu_items').insert(payload);
      return;
    }

    await _db.from('menu_items').update(payload).eq('id', id);
  }

  static Future<void> setAvailability({
    required Object? id,
    required bool isAvailable,
  }) async {
    if (id == null) throw ArgumentError('id is required');
    await _db
        .from('menu_items')
        .update({'is_available': isAvailable})
        .eq('id', id);
  }

  static Future<void> setTrending({
    required Object? id,
    required bool isTrending,
  }) async {
    if (id == null) throw ArgumentError('id is required');
    await _db
        .from('menu_items')
        .update({'is_trending': isTrending})
        .eq('id', id);
  }
}
