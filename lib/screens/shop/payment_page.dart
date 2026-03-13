import 'package:flutter/material.dart';
import 'package:virundhu/screens/orders/order_success_page.dart';
import 'package:virundhu/services/cart_service.dart';
import 'package:virundhu/services/order_service.dart';

class PaymentPage extends StatefulWidget {
  final String address;
  const PaymentPage({super.key, required this.address});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String payment = "Cash on Delivery";
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text(
          "Payment",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700,
        elevation: 1,
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ================= CONTENT =================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Delivery Address"),
                    const SizedBox(height: 8),

                    _infoCard(
                      icon: Icons.location_on,
                      text: widget.address,
                    ),

                    const SizedBox(height: 20),

                    _sectionTitle("Select Payment Method"),
                    const SizedBox(height: 12),

                    _paymentTile(
                      title: "Cash on Delivery",
                      icon: Icons.money,
                      value: "Cash on Delivery",
                    ),

                    _paymentTile(
                      title: "UPI",
                      icon: Icons.qr_code,
                      value: "UPI",
                    ),

                    _paymentTile(
                      title: "Debit / Credit Card",
                      icon: Icons.credit_card,
                      value: "Card",
                    ),

                    const SizedBox(height: 24),

                    _sectionTitle("Order Summary"),
                    const SizedBox(height: 12),

                    _summaryRow("Items", CartService.items.length.toString()),
                    const SizedBox(height: 6),
                    _summaryRow(
                      "Total Amount",
                      "₹${CartService.subtotal}",
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),

            // ================= BOTTOM BAR =================
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 12),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _placeOrder,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                    "Place Order",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= COMPONENTS =================

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final selected = payment == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? Colors.red : Colors.grey.shade300,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: RadioListTile(
        value: value,
        groupValue: payment,
        activeColor: Colors.red.shade700,
        onChanged: (v) => setState(() => payment = v.toString()),
        title: Row(
          children: [
            Icon(icon, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }

  // ================= ACTION =================

  Future<void> _placeOrder() async {
    setState(() => _isLoading = true);
    try {
      await OrderService.placeOrder(
        items: CartService.items,
        total: CartService.subtotal,
        address: widget.address,
        paymentMethod: payment,
      );
      CartService.clear();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OrderSuccessPage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}


