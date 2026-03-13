import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virundhu/screens/admin/admin_panel_page.dart';
import 'package:virundhu/screens/auth/login_signup_screen.dart';
import 'package:virundhu/screens/bookings/book_table_page.dart';
import 'package:virundhu/screens/bookings/my_bookings_page.dart';
import 'package:virundhu/screens/orders/my_orders_page.dart';
import 'package:virundhu/screens/shop/cart_page.dart';
import 'package:virundhu/screens/shop/dishes_page.dart';
import 'package:virundhu/services/auth_service.dart';
import 'package:virundhu/services/menu_service.dart';
import 'package:virundhu/services/user_prefs_service.dart';

import 'profile_page.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final PageController _offerController =
      PageController(viewportFraction: 0.86);

  late AnimationController fadeController;
  late AnimationController pulseController;
  Timer? _offerTimer;
  late final StreamSubscription<AuthState> _authSub;
  bool _redirectingToAdminPanel = false;

  String _dietary = 'all'; // 'all' | 'veg' | 'non-veg'

  List<Map<String, dynamic>> _trendingDishes = [];
  bool _loadingTrending = true;

  final List<Map<String, String>> categories = [
    {"title": "Starters", "icon": "bowl"},
    {"title": "Meals", "icon": "utensils"},
    {"title": "Desserts", "icon": "icecream"},
    {"title": "Beverages", "icon": "drink"},
    {"title": "Milkshakes", "icon": "shake"},
  ];

  final List<String> _offers = [
    "assets/offers/offer1.jpg",
    "assets/offers/offer2.jpg",
    "assets/offers/offer3.jpg",
  ];

  @override
  void initState() {
    super.initState();

    fadeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
          ..forward();

    pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);

    _offerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_offerController.hasClients) {
        final next =
            ((_offerController.page ?? 0).round() + 1) % _offers.length;
        _offerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });

    // Re-render whenever the user signs in or out.
    _authSub = AuthService.authStateChanges.listen((_) {
      if (mounted) {
        setState(() {});
        _loadPref();
        _maybeRedirectAdmin();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRedirectAdmin();
    });

    _loadPref();
    _loadTrending();
  }

  Future<void> _maybeRedirectAdmin() async {
    if (!mounted || _redirectingToAdminPanel || !AuthService.isLoggedIn) return;
    final isAdmin = await AuthService.isCurrentUserAdmin();
    if (!mounted || !isAdmin) return;

    _redirectingToAdminPanel = true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminPanelPage()),
      (_) => false,
    );
  }

  Future<void> _loadPref() async {
    if (!AuthService.isLoggedIn) return;
    final pref = await UserPrefsService.fetchPref();
    if (mounted) setState(() => _dietary = pref);
  }

  Future<void> _loadTrending() async {
    setState(() => _loadingTrending = true);
    try {
      final items = await MenuService.fetchTrending();
      if (mounted) setState(() { _trendingDishes = items; _loadingTrending = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTrending = false);
    }
  }

  Future<void> _cyclePref() async {
    if (!AuthService.isLoggedIn) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginSignupScreen()));
      return;
    }
    const cycle = ['all', 'veg', 'non-veg'];
    final next = cycle[(cycle.indexOf(_dietary) + 1) % cycle.length];
    setState(() => _dietary = next);
    await UserPrefsService.savePref(next);
    if (mounted) {
      final labels = {'all': 'All dishes', 'veg': 'Veg only 🌿', 'non-veg': 'Non-Veg only 🍖'};
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Showing: ${labels[next]}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _prefIcon() {
    switch (_dietary) {
      case 'veg':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade400),
          ),
          child: Text('🌿', style: const TextStyle(fontSize: 16)),
        );
      case 'non-veg':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Text('🍖', style: const TextStyle(fontSize: 16)),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: const Icon(Icons.restaurant_menu, size: 18, color: Colors.grey),
        );
    }
  }

  List<Map<String, dynamic>> get _filteredDishes {
    if (_dietary == 'all') return _trendingDishes;
    return _trendingDishes
        .where((d) => (d['category'] as String).toLowerCase() == _dietary)
        .toList();
  }

  @override
  void dispose() {
    _authSub.cancel();
    _offerTimer?.cancel();
    _offerController.dispose();
    fadeController.dispose();
    pulseController.dispose();
    super.dispose();
  }

  // 🔐 Protected navigation
  void _openProtected(BuildContext context, Widget page) {
    if (AuthService.isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginSignupScreen()),
      );
    }
  }

  IconData getCategoryIcon(String key) {
    switch (key) {
      case "utensils":
        return FontAwesomeIcons.utensils;
      case "icecream":
        return FontAwesomeIcons.iceCream;
      case "drink":
        return FontAwesomeIcons.mugHot;
      case "bowl":
        return FontAwesomeIcons.bowlFood;
      case "shake":
        return FontAwesomeIcons.blender;
      default:
        return Icons.fastfood;
    }
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      bottomNavigationBar: _buildBottomNavBar(),
      body: FadeTransition(
        opacity: fadeController,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                _buildHeroBanner(),
                const SizedBox(height: 16),
                _buildDeliveryLottie(),
                const SizedBox(height: 16),
                _buildOfferCarousel(),
                const SizedBox(height: 20),
                _buildBookTableCard(),
                const SizedBox(height: 20),
                _section(
                  _dietary == 'veg'
                      ? '🌿 Trending Veg'
                      : _dietary == 'non-veg'
                          ? '🍖 Trending Non-Veg'
                          : '🔥 Trending now',
                  () {
                    _openProtected(context, const DishesPage(initialCategory: "All"));
                  },
                ),
                _buildTrendingList(),
                const SizedBox(height: 20),
                _section("🍽 Explore categories", () {
                  _openProtected(context, const DishesPage(initialCategory: "All"));
                }),
                _buildCategoryScroller(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- APP BAR ----------------
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Image.asset("web/icons/virundhu.png", height: 36),
          const SizedBox(width: 10),
          const Text(
            "Virundhu",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
      actions: [
        // Food preference toggle
        GestureDetector(
          onTap: _cyclePref,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: _prefIcon(),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            Icons.person,
            color: AuthService.isLoggedIn ? Colors.green : Colors.black87,
          ),
          onPressed: () {
            if (AuthService.isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginSignupScreen()),
              );
            }
          },
        ),
      ],
    );
  }

  // ---------------- HERO ----------------
  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                "Hot & Fresh Meals\nDelivered Fast",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: 100,
              child: Lottie.asset("assets/lottie/home_animation.json"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryLottie() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            Icon(Icons.timer, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Delivery in 30–40 mins",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ScaleTransition(
              scale: Tween(begin: 0.95, end: 1.1).animate(pulseController),
              child: SizedBox(
                height: 60,
                child: Lottie.asset("assets/lottie/food_delivery.json"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCarousel() {
    return SizedBox(
      height: 170,
      child: PageView.builder(
        controller: _offerController,
        itemCount: _offers.length,
        itemBuilder: (_, index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: AssetImage(_offers[index]),
              fit: BoxFit.cover,
            ),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          GestureDetector(
            onTap: action,
            child: Text("See all",
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildTrendingList() {
    if (_loadingTrending) {
      return const SizedBox(
        height: 230,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_filteredDishes.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No trending dishes available',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return SizedBox(
      height: 230,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filteredDishes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final dish = _filteredDishes[i];
          final imgUrl = dish['image_url'] as String?;
          return GestureDetector(
            onTap: () => _openProtected(
              context,
              DishesPage(initialCategory: dish['category'] as String?),
            ),
            child: Container(
              width: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _trendingImage(imgUrl, 130),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dish['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${dish['price']}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _trendingImage(String? url, double height) {
    final placeholder = Container(
      height: height,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: 36),
    );
    if (url == null || url.isEmpty) return placeholder;
    if (url.startsWith('http')) {
      return Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, p) => p == null ? child : placeholder,
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
  Widget _buildBookTableCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _openProtected(context, const BookTablePage()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepOrange.shade400, Colors.red.shade700],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_restaurant,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book a Table',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Reserve your spot for a perfect dining experience',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryScroller() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final cat = categories[i];
          return GestureDetector(
            onTap: () => _openProtected(
              context,
              DishesPage(initialCategory: cat["title"]),
            ),
            child: Container(
              width: 190,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Icon(getCategoryIcon(cat["icon"]!),
                      color: Colors.red.shade700),
                  const SizedBox(width: 14),
                  Text(cat["title"]!,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: Colors.red.shade700,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "Cart"),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Orders"),
      ],
      onTap: (i) {
        if (i == 1) {
          _openProtected(context, const CartPage());
        } else if (i == 2) {
          _openProtected(context, const MyOrdersPage());
        }
      },
    );
  }

  // ---------------- DRAWER / DASHBOARD ----------------
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.red.shade700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Virundhu",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  AuthService.isLoggedIn
                      ? "Welcome back!"
                      : "Login for better experience",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text("Dishes"),
            onTap: () {
              Navigator.pop(context);
              _openProtected(
                context,
                const DishesPage(initialCategory: "All"),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.table_restaurant, color: Colors.red.shade700),
            title: const Text("Book a Table"),
            onTap: () {
              Navigator.pop(context);
              _openProtected(context, const BookTablePage());
            },
          ),

          ListTile(
            leading: const Icon(Icons.event_seat),
            title: const Text("My Bookings"),
            onTap: () {
              Navigator.pop(context);
              _openProtected(context, const MyBookingsPage());
            },
          ),

          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text("Cart"),
            onTap: () {
              Navigator.pop(context);
              _openProtected(context, const CartPage());
            },
          ),

          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text("My Orders"),
            onTap: () {
              Navigator.pop(context);
              _openProtected(
                context,
                const MyOrdersPage(),
              );
            },
          ),

          const Divider(),

          if (!AuthService.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text("Login / Signup"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginSignupScreen()),
              ),
            ),

          if (AuthService.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                await AuthService.logout();
                if (mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

