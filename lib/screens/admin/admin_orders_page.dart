import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virundhu/screens/core/profile_page.dart';
import 'package:virundhu/screens/orders/order_details_page.dart';
import 'package:virundhu/services/order_service.dart';

class AdminOrdersPage extends StatefulWidget {
  final bool showAppBar;

  const AdminOrdersPage({super.key, this.showAppBar = true});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  static const List<String> _filters = [
    'All',
    'Today',
    'Pending',
    'Delivered',
    'Cancelled',
  ];

  static const List<String> _statuses = [
    'Placed',
    'Accepted',
    'Preparing',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];

  late Future<List<Map<String, dynamic>>> _ordersFuture;
  late final RealtimeChannel _ordersChannel;
  final Set<String> _updatingOrderIds = <String>{};
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _ordersFuture = OrderService.fetchAllOrders();
    _ordersChannel = Supabase.instance.client
        .channel('admin-orders-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) {
              _refresh();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) {
            if (mounted) {
              _refresh();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_ordersChannel);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = OrderService.fetchAllOrders();
    setState(() {
      _ordersFuture = future;
    });
    await future;
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}  "
        "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  DateTime _safeDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  String _displayValue(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  bool _isPendingStatus(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'accepted':
      case 'preparing':
      case 'out for delivery':
        return true;
      default:
        return false;
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> orders) {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Today':
        return orders
            .where((order) => _isSameDay(_safeDate(order['date']), now))
            .toList();
      case 'Pending':
        return orders
            .where((order) => _isPendingStatus(_displayValue(order['status'])))
            .toList();
      case 'Delivered':
        return orders
            .where((order) =>
                _displayValue(order['status']).toLowerCase() == 'delivered')
            .toList();
      case 'Cancelled':
        return orders
            .where((order) =>
                _displayValue(order['status']).toLowerCase() == 'cancelled')
            .toList();
      default:
        return orders;
    }
  }

  String _emptyFilterMessage() {
    switch (_selectedFilter) {
      case 'Today':
        return 'No orders were placed today.';
      case 'Pending':
        return 'There are no active pending orders right now.';
      case 'Delivered':
        return 'No delivered orders found.';
      case 'Cancelled':
        return 'No cancelled orders found.';
      default:
        return 'New customer orders will appear here.';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.blue.shade700;
      case 'preparing':
        return Colors.orange.shade800;
      case 'out for delivery':
        return Colors.deepPurple.shade600;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.red.shade700;
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> order, String status) async {
    final orderId = order['id'];
    final orderKey = orderId?.toString();
    if (orderKey == null || orderKey.isEmpty) return;

    setState(() => _updatingOrderIds.add(orderKey));
    try {
      await OrderService.updateOrderStatus(orderId: orderId, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $status'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingOrderIds.remove(orderKey));
      }
    }
  }

  Future<void> _showStatusSheet(Map<String, dynamic> order) async {
    final currentStatus = _displayValue(order['status']);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text(
                    'Update Order Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Current: $currentStatus'),
                ),
                for (final status in _statuses)
                  ListTile(
                    leading: Icon(
                      status == currentStatus
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _statusColor(status),
                    ),
                    title: Text(status),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (status != currentStatus) {
                        _changeStatus(order, status);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Incoming Orders',
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
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _AdminOrdersState(
              icon: Icons.lock_outline,
              title: 'Unable to load admin orders',
              message:
                  'This account may not have permission to read all orders yet.\n${snapshot.error}',
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }

          final orders = snapshot.data ?? const [];
          if (orders.isEmpty) {
            return _AdminOrdersState(
              icon: Icons.inbox_outlined,
              title: 'No incoming orders',
              message: 'New customer orders will appear here.',
              actionLabel: 'Refresh',
              onAction: _refresh,
            );
          }

          final filteredOrders = _applyFilter(orders);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = filter == _selectedFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          selectedColor: Colors.red.shade700,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          onSelected: (_) {
                            setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${filteredOrders.length} orders',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (filteredOrders.isEmpty)
                  _AdminOrdersState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No orders for $_selectedFilter',
                    message: _emptyFilterMessage(),
                    actionLabel: 'Refresh',
                    onAction: _refresh,
                  )
                else
                  ...List.generate(filteredOrders.length, (index) {
                    final order = filteredOrders[index];
                final date = _safeDate(order['date']);
                final status = _displayValue(order['status']);
                final orderKey = order['id']?.toString() ?? 'unknown-$index';
                final isUpdating = _updatingOrderIds.contains(orderKey);
                final customerName = _displayValue(
                  order['customer_name'],
                  fallback: _displayValue(order['user_id']),
                );
                final customerPhone = _displayValue(order['customer_phone']);

                    return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.red.shade700,
                      ),
                    ),
                    title: Text(
                      customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text('Total: ₹${order['total'] ?? 0}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Phone: $customerPhone'),
                          const SizedBox(height: 4),
                          Text('Ordered on: ${_formatDate(date)}'),
                          const SizedBox(height: 4),
                          Text(
                            'Address: ${_displayValue(order['address'])}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isUpdating
                                  ? null
                                  : () => _showStatusSheet(order),
                              icon: isUpdating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.edit_note_outlined),
                              label: Text(
                                isUpdating ? 'Updating...' : 'Update Status',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailsPage(order: order),
                        ),
                      );
                    },
                  ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminOrdersState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _AdminOrdersState({
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
            Icon(icon, size: 64, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
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