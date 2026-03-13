import 'package:supabase_flutter/supabase_flutter.dart';

class BookingService {
  static final _client = Supabase.instance.client;

  /// Fetches all table bookings (admin use). Enriches each row with
  /// customer name, phone, and email from the profiles table.
  static Future<List<Map<String, dynamic>>> fetchAllBookings() async {
    final data = await _client
        .from('table_bookings')
        .select()
        .order('created_at', ascending: false);

    final bookings = _normalize(data);

    final userIds = bookings
        .map((b) => b['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (userIds.isEmpty) return bookings;

    try {
      final profiles = await _client
          .from('profiles')
          .select()
          .inFilter('id', userIds);

      final profileMap = {
        for (final p in profiles as List)
          (p['id']?.toString() ?? ''): Map<String, dynamic>.from(p as Map),
      };

      for (final b in bookings) {
        final profile = profileMap[b['user_id']?.toString() ?? ''];
        if (profile == null) continue;
        b['customer_name'] = profile['full_name'];
        b['customer_phone'] = profile['phone'];
        b['customer_email'] = profile['email'];
      }
    } catch (_) {}

    return bookings;
  }

  static Future<void> updateBookingStatus({
    required Object? bookingId,
    required String status,
  }) async {
    if (bookingId == null) throw ArgumentError('bookingId is required');

    await _client
        .from('table_bookings')
        .update({'status': status})
        .eq('id', bookingId);
  }

  static List<Map<String, dynamic>> _normalize(dynamic data) {
    return (data as List).map<Map<String, dynamic>>((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final raw = map['created_at'];
      map['created_date'] = (raw is DateTime)
          ? raw
          : DateTime.tryParse(raw.toString()) ?? DateTime.now();
      return map;
    }).toList();
  }
}
