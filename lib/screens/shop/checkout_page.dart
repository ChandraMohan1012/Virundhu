import 'package:flutter/material.dart';
import 'payment_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _instructionCtrl = TextEditingController();

  String selectedLabel = "Home";

  @override
  void dispose() {
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _instructionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700,
        elevation: 1,
      ),

      /// 🔹 BODY
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Delivery Details"),

                    const SizedBox(height: 14),

                    /// ADDRESS LABELS
                    Row(
                      children: [
                        _addressChip("Home"),
                        const SizedBox(width: 10),
                        _addressChip("Work"),
                        const SizedBox(width: 10),
                        _addressChip("Other"),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// ADDRESS FIELD
                    _card(
                      child: TextField(
                        controller: _addressCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              "House no, Street, Area, City, Pincode",
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// PHONE NUMBER
                    _card(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: "Contact number",
                          prefixIcon: Icon(Icons.phone),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// DELIVERY INSTRUCTIONS
                    _card(
                      child: TextField(
                        controller: _instructionCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: "Delivery instructions (optional)",
                          prefixIcon: Icon(Icons.notes),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    /// INFO TEXT
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Your number may be used to contact you during delivery",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            /// 🔴 STICKY BOTTOM BUTTON
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
                  onPressed: _continueToPayment,
                  child: const Text(
                    "Continue to Payment",
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

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8),
        ],
      ),
      child: child,
    );
  }

  Widget _addressChip(String label) {
    final bool selected = selectedLabel == label;

    return GestureDetector(
      onTap: () => setState(() => selectedLabel = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.red.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.red : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ================= ACTION =================

  void _continueToPayment() {
    if (_addressCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill address and contact number"),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          address:
              "${selectedLabel}: ${_addressCtrl.text.trim()}",
        ),
      ),
    );
  }
}
