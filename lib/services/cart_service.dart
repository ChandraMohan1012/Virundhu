class CartService {
  static final List<Map<String, dynamic>> _cartItems = [];

  static List<Map<String, dynamic>> get items => _cartItems;

  static void addItem(Map<String, dynamic> dish) {
    final id = dish['id'].toString();
    final index = _cartItems.indexWhere((e) => e['id'] == id);

    if (index != -1) {
      _cartItems[index]['qty'] = (_cartItems[index]['qty'] as int) + 1;
    } else {
      _cartItems.add({
        "id": id,
        "name": dish['name'],
        "img": dish['image_url'] ?? dish['img'] ?? '',
        "price": dish['price'], // keep as int
        "qty": 1,
      });
    }
  }

  static void removeItem(String id) {
    _cartItems.removeWhere((e) => e['id'] == id);
  }

  static void increaseQty(String id) {
    final item = _cartItems.firstWhere((e) => e['id'] == id);
    item['qty'] = (item['qty'] as int) + 1;
  }

  static void decreaseQty(String id) {
    final item = _cartItems.firstWhere((e) => e['id'] == id);
    if ((item['qty'] as int) > 1) {
      item['qty'] = (item['qty'] as int) - 1;
    }
  }

  /// ✅ FIXED SUBTOTAL CALCULATION
  static int get subtotal {
    int total = 0;

    for (var item in _cartItems) {
      final int price = item['price'] as int;
      final int qty = item['qty'] as int;

      total += price * qty;
    }

    return total;
  }

  static void clear() {
    _cartItems.clear();
  }
}
