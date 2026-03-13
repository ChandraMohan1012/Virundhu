import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  static final _client = Supabase.instance.client;

  static Future<void> placeOrder({
    required List items,
    required int total,
    required String address,
    required String paymentMethod,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await _client.from('orders').insert({
      'user_id': userId,
      'items': items,
      'total': total,
      'address': address,
      'payment': paymentMethod,
      'status': 'Placed',
    });
  }

  /// Fetches orders for the current user ordered by newest first.
  /// Normalises Supabase `created_at` string → `date` as DateTime so
  /// existing screens that reference order['date'] continue to work.
  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('orders')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return _normalizeOrders(data);
  }

  static Future<List<Map<String, dynamic>>> fetchAllOrders() async {
    final data = await _client
        .from('orders')
        .select()
        .order('created_at', ascending: false);

    final orders = _normalizeOrders(data);
    final userIds = orders
        .map((order) => order['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (userIds.isEmpty) return orders;

    try {
      final profiles = await _client
          .from('profiles')
          .select()
          .inFilter('id', userIds);

      final profileMap = {
        for (final profile in profiles as List)
          (profile['id']?.toString() ?? ''): Map<String, dynamic>.from(profile as Map),
      };

      for (final order in orders) {
        final profile = profileMap[order['user_id']?.toString() ?? ''];
        if (profile == null) continue;
        order['customer_name'] = profile['full_name'];
        order['customer_phone'] = profile['phone'];
        order['customer_email'] = profile['email'];
      }
    } catch (_) {}

    return orders;
  }

  static Future<void> updateOrderStatus({
    required Object? orderId,
    required String status,
  }) async {
    if (orderId == null) {
      throw ArgumentError('orderId is required');
    }

    await _client
        .from('orders')
          .update({'status': status})
        .eq('id', orderId);
  }

  static List<Map<String, dynamic>> _normalizeOrders(dynamic data) {
    return (data as List).map<Map<String, dynamic>>((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final raw = map['created_at'];
      map['date'] = (raw is DateTime)
          ? raw
          : DateTime.tryParse(raw.toString()) ?? DateTime.now();
      return map;
    }).toList();
  }
}
