import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virundhu/screens/core/profile_page.dart';
import 'package:virundhu/services/booking_service.dart';

class AdminBookingsPage extends StatefulWidget {
  final bool showAppBar;

  const AdminBookingsPage({super.key, this.showAppBar = true});

  @override
  State<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends State<AdminBookingsPage> {
  static const List<String> _filters = [
    'All',
    'Today',
    'Pending',
    'Confirmed',
    'Cancelled',
  ];

  static const List<String> _statuses = [
    'Pending',
    'Confirmed',
    'Cancelled',
  ];

  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  late final RealtimeChannel _channel;
  final Set<String> _updatingIds = {};
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _bookingsFuture = BookingService.fetchAllBookings();

    _channel = Supabase.instance.client
        .channel('admin-bookings-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'table_bookings',
          callback: (_) {
            if (mounted) _refresh();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) {
            if (mounted) _refresh();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = BookingService.fetchAllBookings();
    setState(() {
      _bookingsFuture = future;
    });
    await future;
  }

  // ── Helpers ────────────────────────────────────────────────────

  String _display(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? fallback : text;
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}  '
      '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

  DateTime _safeDate(dynamic v) =>
      v is DateTime ? v : DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> list) {
    switch (_selectedFilter) {
      case 'Today':
        return list
            .where((b) => _isToday(_safeDate(b['created_date'])))
            .toList();
      case 'Pending':
        return list
            .where((b) => _display(b['status']).toLowerCase() == 'pending')
            .toList();
      case 'Confirmed':
        return list
            .where((b) => _display(b['status']).toLowerCase() == 'confirmed')
            .toList();
      case 'Cancelled':
        return list
            .where((b) => _display(b['status']).toLowerCase() == 'cancelled')
            .toList();
      default:
        return list;
    }
  }

  String _emptyMessage() {
    switch (_selectedFilter) {
      case 'Today':
        return 'No bookings were made today.';
      case 'Pending':
        return 'No pending bookings right now.';
      case 'Confirmed':
        return 'No confirmed bookings found.';
      case 'Cancelled':
        return 'No cancelled bookings found.';
      default:
        return 'New table bookings will appear here.';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  // ── Status update ──────────────────────────────────────────────

  Future<void> _changeStatus(Map<String, dynamic> booking, String status) async {
    final bookingId = booking['id'];
    final key = bookingId?.toString();
    if (key == null || key.isEmpty) return;

    setState(() => _updatingIds.add(key));
    try {
      await BookingService.updateBookingStatus(
          bookingId: bookingId, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking status updated to $status'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update booking: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingIds.remove(key));
    }
  }

  Future<void> _showStatusSheet(Map<String, dynamic> booking) async {
    final current = _display(booking['status']);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'Update Booking Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Current: $current'),
              ),
              for (final s in _statuses)
                ListTile(
                  leading: Icon(
                    s == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: _statusColor(s),
                  ),
                  title: Text(s),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (s != current) _changeStatus(booking, s);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Table Bookings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.red.shade700,
              actions: [
                IconButton(
                  tooltip: 'Admin Profile',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                ),
              ],
            )
          : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.lock_outline,
              title: 'Unable to load bookings',
              message:
                  'This account may not have permission to read all bookings.\n${snapshot.error}',
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }

          final all = snapshot.data ?? [];
          if (all.isEmpty) {
            return _EmptyState(
              icon: Icons.table_restaurant_outlined,
              title: 'No bookings yet',
              message: _emptyMessage(),
              actionLabel: 'Refresh',
              onAction: _refresh,
            );
          }

          final filtered = _applyFilter(all);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Filter chips ───────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final selected = filter == _selectedFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: selected,
                          selectedColor: Colors.red.shade700,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          onSelected: (_) =>
                              setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  '${filtered.length} bookings',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // ── List or empty ──────────────────────────────
                if (filtered.isEmpty)
                  _EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No bookings for $_selectedFilter',
                    message: _emptyMessage(),
                    actionLabel: 'Refresh',
                    onAction: _refresh,
                  )
                else
                  ...filtered.map((booking) => _bookingCard(booking)).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final status = _display(b['status'], fallback: 'Pending');
    final key = b['id']?.toString() ?? '';
    final isUpdating = _updatingIds.contains(key);
    final customerName = _display(
      b['customer_name'],
      fallback: _display(b['user_id']),
    );
    final phone    = _display(b['customer_phone']);
    final date     = _display(b['date']);
    final time     = (b['time'] as String? ?? '').length >= 5
        ? (b['time'] as String).substring(0, 5)
        : _display(b['time']);
    final guests   = '${b['guests'] ?? '—'} guests';
    final notes    = _display(b['notes'], fallback: '');
    final created  = _formatDate(_safeDate(b['created_date']));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.table_restaurant, color: Colors.red.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _detailRow(Icons.phone_outlined, 'Phone', phone),
                const SizedBox(height: 8),
                _detailRow(Icons.calendar_today, 'Date', date),
                const SizedBox(height: 8),
                _detailRow(Icons.access_time, 'Time', time),
                const SizedBox(height: 8),
                _detailRow(Icons.people_outline, 'Guests', guests),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _detailRow(Icons.note_alt_outlined, 'Notes', notes),
                ],
                const SizedBox(height: 8),
                _detailRow(Icons.schedule_outlined, 'Booked on', created),
                const SizedBox(height: 12),

                // Update status button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        isUpdating ? null : () => _showStatusSheet(b),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_note_outlined),
                    label: Text(
                        isUpdating ? 'Updating...' : 'Update Status'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.red.shade400),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
              fontSize: 13, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Empty / error state widget ─────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
