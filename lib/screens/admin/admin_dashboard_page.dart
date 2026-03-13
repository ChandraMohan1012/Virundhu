import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virundhu/screens/core/profile_page.dart';
import 'package:virundhu/services/booking_service.dart';
import 'package:virundhu/services/menu_service.dart';
import 'package:virundhu/services/order_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final bool showAppBar;

  const AdminDashboardPage({super.key, this.showAppBar = true});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<_AdminDashboardData> _dashboardFuture;
  late final RealtimeChannel _dashboardChannel;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
    _dashboardChannel = Supabase.instance.client
        .channel('admin-dashboard-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) _refresh();
          },
        )
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
          table: 'menu_items',
          callback: (_) {
            if (mounted) _refresh();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_dashboardChannel);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = _loadDashboard();
    setState(() {
      _dashboardFuture = future;
    });
    await future;
  }

  Future<_AdminDashboardData> _loadDashboard() async {
    final results = await Future.wait<dynamic>([
      OrderService.fetchAllOrders(),
      BookingService.fetchAllBookings(),
      MenuService.fetchAllMenuAdmin(),
    ]);

    final orders = List<Map<String, dynamic>>.from(results[0] as List);
    final bookings = List<Map<String, dynamic>>.from(results[1] as List);
    final menuItems = List<Map<String, dynamic>>.from(results[2] as List);
    final now = DateTime.now();

    final todayOrders = orders.where((o) => _isSameDay(_safeDate(o['date']), now)).toList();
    final pendingOrders = orders.where((o) {
      final s = _display(o['status']).toLowerCase();
      return s == 'placed' || s == 'accepted' || s == 'preparing' || s == 'out for delivery';
    }).toList();

    final todayBookings = bookings.where((b) {
      final parsed = DateTime.tryParse(b['date']?.toString() ?? '');
      final date = parsed ?? _safeDate(b['created_date']);
      return _isSameDay(date, now);
    }).toList();

    final revenueTodayOrders = todayOrders.where((o) => _display(o['status']).toLowerCase() != 'cancelled').toList();
    final revenueToday = revenueTodayOrders.fold<int>(0, (sum, o) {
      final total = o['total'];
      if (total is int) return sum + total;
      return sum + (int.tryParse(total?.toString() ?? '') ?? 0);
    });

    final cancelledOrders = orders.where((o) => _display(o['status']).toLowerCase() == 'cancelled').toList();
    final cancelledBookings = bookings.where((b) => _display(b['status']).toLowerCase() == 'cancelled').toList();
    final outOfStockItems = menuItems.where((m) => m['is_available'] == false).toList();

    return _AdminDashboardData(
      todayOrders: todayOrders,
      pendingOrders: pendingOrders,
      todayBookings: todayBookings,
      revenueTodayOrders: revenueTodayOrders,
      cancelledOrders: cancelledOrders,
      cancelledBookings: cancelledBookings,
      revenueToday: revenueToday,
      outOfStockItems: outOfStockItems,
      recentOrders: orders.take(5).toList(),
      recentBookings: bookings.take(5).toList(),
    );
  }

  DateTime _safeDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  String _display(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  ({Color card, Color icon, Color text}) _metricTheme(String title) {
    switch (title) {
      case 'Today\'s Orders':
        return (
          card: const Color(0xFFFFF2F1),
          icon: const Color(0xFFD32F2F),
          text: const Color(0xFFB71C1C),
        );
      case 'Pending Orders':
        return (
          card: const Color(0xFFFFF8E6),
          icon: const Color(0xFFEF6C00),
          text: const Color(0xFFE65100),
        );
      case 'Today\'s Bookings':
        return (
          card: const Color(0xFFEFF8F2),
          icon: const Color(0xFF2E7D32),
          text: const Color(0xFF1B5E20),
        );
      case 'Revenue Today':
        return (
          card: const Color(0xFFE9F6FF),
          icon: const Color(0xFF0277BD),
          text: const Color(0xFF01579B),
        );
      case 'Cancelled':
        return (
          card: const Color(0xFFFFECEC),
          icon: const Color(0xFFC62828),
          text: const Color(0xFFB71C1C),
        );
      default:
        return (
          card: const Color(0xFFF3F0FF),
          icon: const Color(0xFF5E35B1),
          text: const Color(0xFF4527A0),
        );
    }
  }

  void _showMetricDetails(String title, List<Widget> rows) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Flexible(
                child: rows.isEmpty
                    ? const Center(child: Text('No details found'))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => rows[i],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailCard({required String title, String? subtitle, String? trailing}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(trailing, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: FutureBuilder<_AdminDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dashboard_customize_outlined, size: 64),
                    const SizedBox(height: 16),
                    const Text('Unable to load admin dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Today at a glance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  children: [
                    _metricCard('Today\'s Orders', data.todayOrders.length.toString(), Icons.receipt_long_outlined, () {
                      _showMetricDetails('Today\'s Orders', data.todayOrders.map((o) => _detailCard(
                        title: _display(o['customer_name'], fallback: _display(o['id'])),
                        subtitle: 'Rs.${o['total'] ?? 0}',
                        trailing: _display(o['status']),
                      )).toList());
                    }),
                    _metricCard('Pending Orders', data.pendingOrders.length.toString(), Icons.pending_actions_outlined, () {
                      _showMetricDetails('Pending Orders', data.pendingOrders.map((o) => _detailCard(
                        title: _display(o['customer_name'], fallback: _display(o['id'])),
                        subtitle: 'Rs.${o['total'] ?? 0}',
                        trailing: _display(o['status']),
                      )).toList());
                    }),
                    _metricCard('Today\'s Bookings', data.todayBookings.length.toString(), Icons.table_restaurant_outlined, () {
                      _showMetricDetails('Today\'s Bookings', data.todayBookings.map((b) => _detailCard(
                        title: _display(b['customer_name'], fallback: _display(b['id'])),
                        subtitle: '${_display(b['date'])}  ${_display(b['time'])}',
                        trailing: _display(b['status']),
                      )).toList());
                    }),
                    _metricCard('Revenue Today', 'Rs.${data.revenueToday}', Icons.currency_rupee_outlined, () {
                      _showMetricDetails('Revenue Today', data.revenueTodayOrders.map((o) => _detailCard(
                        title: _display(o['customer_name'], fallback: _display(o['id'])),
                        subtitle: 'Included in revenue',
                        trailing: 'Rs.${o['total'] ?? 0}',
                      )).toList());
                    }),
                    _metricCard('Cancelled', (data.cancelledOrders.length + data.cancelledBookings.length).toString(), Icons.cancel_outlined, () {
                      _showMetricDetails('Cancelled', [
                        ...data.cancelledOrders.map((o) => _detailCard(
                          title: 'Order: ${_display(o['customer_name'], fallback: _display(o['id']))}',
                          subtitle: 'Rs.${o['total'] ?? 0}',
                          trailing: 'Cancelled',
                        )),
                        ...data.cancelledBookings.map((b) => _detailCard(
                          title: 'Booking: ${_display(b['customer_name'], fallback: _display(b['id']))}',
                          subtitle: '${_display(b['date'])}  ${_display(b['time'])}',
                          trailing: 'Cancelled',
                        )),
                      ]);
                    }),
                    _metricCard('Out of Stock', data.outOfStockItems.length.toString(), Icons.inventory_2_outlined, () {
                      _showMetricDetails('Out of Stock', data.outOfStockItems.map((m) => _detailCard(
                        title: _display(m['name']),
                        subtitle: _display(m['category']),
                        trailing: 'Rs.${m['price'] ?? 0}',
                      )).toList());
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionCard(
                  title: 'Recent Orders',
                  child: Column(
                    children: data.recentOrders.isEmpty
                      ? const [Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No recent orders'))]
                      : data.recentOrders.map((o) => _recentOrderCard(o)).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionCard(
                  title: 'Recent Bookings',
                  child: Column(
                    children: data.recentBookings.isEmpty
                      ? const [Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No recent bookings'))]
                      : data.recentBookings.map((b) => _recentBookingCard(b)).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, VoidCallback onTap) {
    final theme = _metricTheme(title);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.icon),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.text),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _recentOrderCard(Map<String, dynamic> order) {
    final status = _display(order['status']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_display(order['customer_name'], fallback: _display(order['id'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Rs.${order['total'] ?? 0}'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(999)),
            child: Text(status, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _recentBookingCard(Map<String, dynamic> booking) {
    final status = _display(booking['status']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_display(booking['customer_name'], fallback: _display(booking['id'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${booking['date'] ?? '-'}  ${booking['time'] ?? ''}'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(999)),
            child: Text(status, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardData {
  final List<Map<String, dynamic>> todayOrders;
  final List<Map<String, dynamic>> pendingOrders;
  final List<Map<String, dynamic>> todayBookings;
  final List<Map<String, dynamic>> revenueTodayOrders;
  final List<Map<String, dynamic>> cancelledOrders;
  final List<Map<String, dynamic>> cancelledBookings;
  final int revenueToday;
  final List<Map<String, dynamic>> outOfStockItems;
  final List<Map<String, dynamic>> recentOrders;
  final List<Map<String, dynamic>> recentBookings;

  const _AdminDashboardData({
    required this.todayOrders,
    required this.pendingOrders,
    required this.todayBookings,
    required this.revenueTodayOrders,
    required this.cancelledOrders,
    required this.cancelledBookings,
    required this.revenueToday,
    required this.outOfStockItems,
    required this.recentOrders,
    required this.recentBookings,
  });
}
