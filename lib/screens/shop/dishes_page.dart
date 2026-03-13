import 'package:flutter/material.dart';
import 'package:virundhu/services/auth_service.dart';
import 'package:virundhu/services/cart_service.dart';
import 'package:virundhu/services/menu_service.dart';
import 'package:virundhu/services/user_prefs_service.dart';
import 'cart_page.dart';

class DishesPage extends StatefulWidget {
  final String? initialCategory;
  const DishesPage({super.key, this.initialCategory});

  @override
  State<DishesPage> createState() => _DishesPageState();
}

class _DishesPageState extends State<DishesPage>
    with SingleTickerProviderStateMixin {
  final List<String> _tabs = const [
    'All',
    'Veg',
    'Non-Veg',
    'Starters',
    'Meals',
    'Beverages',
    'Desserts',
    'Milkshakes',
  ];

  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _menu = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    int initialIndex = 0;
    if (widget.initialCategory != null) {
      final idx = _tabs.indexWhere(
        (t) => t.toLowerCase() == widget.initialCategory!.toLowerCase(),
      );
      if (idx != -1) initialIndex = idx;
    }

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );

    _searchCtrl.addListener(_applyFilter);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _applyFilter();
    });

    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final items = await MenuService.fetchMenu();
      if (!mounted) return;
      setState(() {
        _menu = items;
        _isLoading = false;
      });
      _applyFilter();

      // Auto-jump to dietary preference tab if no category was explicitly passed.
      if (widget.initialCategory == null && AuthService.isLoggedIn) {
        final pref = await UserPrefsService.fetchPref();
        if (!mounted) return;
        int prefIndex = 0;
        if (pref == 'veg') prefIndex = _tabs.indexOf('Veg');
        if (pref == 'non-veg') prefIndex = _tabs.indexOf('Non-Veg');
        if (prefIndex > 0) _tabController.animateTo(prefIndex);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _loadError = e.toString(); });
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase();
    final tab = _tabs[_tabController.index];

    List<Map<String, dynamic>> items;

    if (tab == 'All') {
      items = List.from(_menu);
    } else if (tab == 'Veg' || tab == 'Non-Veg') {
      final tabLower = tab.toLowerCase();
      items = _menu
          .where((m) =>
              (m['category'] as String? ?? '').toLowerCase() == tabLower)
          .toList();
    } else {
      items = _menu.where((m) {
        final tags = ((m['tags'] as List?) ?? []).join(' ').toLowerCase();
        return tags.contains(tab.toLowerCase()) ||
            (m['category'] as String).toLowerCase() == tab.toLowerCase();
      }).toList();
    }

    if (query.isNotEmpty) {
      items = items
          .where((m) =>
              (m['name'] as String).toLowerCase().contains(query) ||
              (m['category'] as String).toLowerCase().contains(query))
          .toList();
    }

    setState(() => _filtered = items);
  }

  int _getQty(dynamic id) {
    final sid = id.toString();
    final item = CartService.items.where((e) => e['id'] == sid);
    return item.isEmpty ? 0 : item.first['qty'];
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, (_) => _buildGrid()),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text("Dishes", style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.red.shade700,
      elevation: 1,
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            ).then((_) => setState(() {}));
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart),
              if (CartService.items.isNotEmpty)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      CartService.items.length.toString(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
            ],
          ),
        )
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Column(
          children: [
            _buildSearch(),
            Container(color: Colors.white, child: _buildTabs()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: "Search for dishes, meals…",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: Colors.red.shade700,
      unselectedLabelColor: Colors.grey,
      indicatorWeight: 3,
      tabs: _tabs.map((e) => Tab(text: e)).toList(),
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Could not load dishes'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadMenu,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text('No dishes found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (_, i) => _dishCard(_filtered[i]),
    );
  }

  // ================= DISH CARD =================

  Widget _dishCard(Map<String, dynamic> dish) {
    final qty = _getQty(dish['id']);
    final isVeg = dish['category'] == 'Veg';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: _menuImage(
                    dish['image_url'] as String?, 140, dish['category'] as String? ?? ''),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isVeg ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isVeg ? "VEG" : "NON-VEG",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish['name'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      "₹${dish['price']}",
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    qty == 0
                        ? _addBtn(dish)
                        : _qtyController(dish, qty),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _menuImage(String? url, double height, [String category = '']) {
    String fallbackAsset;
    final cat = category.toLowerCase();
    if (cat.contains('biryani') || cat.contains('meals') || cat.contains('veg')) {
      fallbackAsset = 'assets/food/meals.jpg';
    } else if (cat.contains('non-veg') || cat.contains('grill') || cat.contains('starter')) {
      fallbackAsset = 'assets/food/grill.jpg';
    } else {
      fallbackAsset = 'assets/food/biryani.jpg';
    }

    final placeholder = Image.asset(
      fallbackAsset,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: 40),
      ),
    );
    if (url == null || url.isEmpty) return placeholder;
    if (url.startsWith('http')) {
      return Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugPrint('IMAGE ERROR for $url => $error');
          return placeholder;
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            width: double.infinity,
            color: Colors.grey.shade100,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }
    return Image.asset(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  Widget _addBtn(Map<String, dynamic> dish) {
    return InkWell(
      onTap: () => setState(() => CartService.addItem(dish)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "ADD",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _qtyController(Map<String, dynamic> dish, int qty) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade700),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _qtyBtn(Icons.remove, () {
            setState(() => CartService.decreaseQty(dish['id'].toString()));
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              qty.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _qtyBtn(Icons.add, () {
            setState(() => CartService.addItem(dish));
          }),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: Colors.red.shade700),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
}




