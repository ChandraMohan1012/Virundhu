import 'package:flutter/material.dart';
import 'package:virundhu/screens/shop/cart_page.dart';
import 'package:virundhu/services/cart_service.dart';

import 'order_status_stepper.dart';

class OrderDetailsPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsPage({super.key, required this.order});

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}  "
        "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  DateTime _safeDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  Future<void> _reorder(BuildContext context, List items) async {
    for (final item in items) {
      final map = Map<String, dynamic>.from(item as Map);
      final quantity = map['qty'] is int
          ? map['qty'] as int
          : int.tryParse(map['qty']?.toString() ?? '') ?? 1;

      for (var index = 0; index < quantity; index++) {
        CartService.addItem({
          'id': map['id'],
          'name': map['name'],
          'image_url': map['image_url'] ?? map['img'],
          'img': map['img'],
          'price': map['price'],
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Items added to cart'),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List items = (order['items'] as List?) ?? const [];
    final customerName = _valueOrNull(order['customer_name']);
    final customerPhone = _valueOrNull(order['customer_phone']);
    final customerEmail = _valueOrNull(order['customer_email']);
    final userId = _valueOrNull(order['user_id']);
    final hasCustomerInfo = customerName != null ||
        customerPhone != null ||
        customerEmail != null ||
        userId != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Order Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: "Order Summary",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row("Order ID", order['id']),
                _row("Order Date", _formatDate(_safeDate(order['date']))),
                _row("Status", order['status']),
              ],
            ),
          ),

          _sectionCard(
            title: "Live Tracking",
            child: OrderStatusStepper(
              currentStatus: _valueOrFallback(order['status'], fallback: 'Placed'),
            ),
          ),

          if (hasCustomerInfo)
            _sectionCard(
              title: "Customer",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customerName != null) _row("Name", customerName),
                  if (customerPhone != null) _row("Phone", customerPhone),
                  if (customerEmail != null) _row("Email", customerEmail),
                  if (userId != null) _row("User ID", userId),
                ],
              ),
            ),

          _sectionCard(
            title: "Delivery Address",
            child: Text(
              _valueOrFallback(order['address']),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          _sectionCard(
            title: "Payment Method",
            child: Text(
              _valueOrFallback(order['payment']),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          _sectionCard(
            title: "Items",
            child: Column(
              children: items.map<Widget>((item) {
                final map = Map<String, dynamic>.from(item as Map);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _valueOrFallback(map['name']),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        "₹${map['price'] ?? 0} × ${map['qty'] ?? 0}",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          _sectionCard(
            title: "Total Amount",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "₹${order['total'] ?? 0}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _reorder(context, items),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.replay_outlined),
                      label: const Text('Reorder These Items'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _valueOrFallback(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  String? _valueOrNull(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Text(
            _valueOrFallback(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
