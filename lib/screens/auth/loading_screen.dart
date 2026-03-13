import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:virundhu/screens/core/home_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {

  late AnimationController _logoController;
  late AnimationController _bgController;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // 🌟 Logo breathing animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 🌈 Background slow movement animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // ⏳ Navigation
    _navTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _logoController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (_, __) {
          return Container(
            // 🌅 DARKER, ANIMATED BACKGROUND
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFFFFE6D6), // darker cream
                  Color(0xFFFFC89A), // rich peach
                  Color(0xFFD96B00), // deep amber
                ],
                begin: Alignment(0, -1 + (_bgController.value * 0.2)),
                end: Alignment(0, 1 - (_bgController.value * 0.2)),
              ),
            ),

            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // ✨ Glow + Logo
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (_, __) {
                      return Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB703)
                                  .withOpacity(0.28 + (_logoController.value * 0.2)),
                              blurRadius: 40,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: 1 + (_logoController.value * 0.04),
                          child: Lottie.asset(
                            'assets/lottie/Virundhu_loading.json',
                            width: 220,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // 🍽 App name
                  const Text(
                    "Virundhu",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: Color(0xFF7C2D12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Serving happiness...",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.brown,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 🔥 Modern loading bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 160,
                      height: 6,
                      child: LinearProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFD96B00),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
