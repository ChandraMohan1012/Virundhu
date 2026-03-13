import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virundhu/screens/admin/admin_panel_page.dart';
import 'package:virundhu/screens/core/home_screen.dart';
import 'package:virundhu/services/auth_service.dart';

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  StreamSubscription<AuthState>? _authSub;

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Listen for OAuth redirect (Google sign-in completes in browser and
    // deep-links back — Supabase emits a signedIn event).
    _authSub = AuthService.authStateChanges.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn &&
          mounted &&
          _isGoogleLoading) {
        setState(() => _isGoogleLoading = false);
        await _routeAfterAuth();
      }
    });
  }

  Future<void> _routeAfterAuth() async {
    final isAdmin = await AuthService.isCurrentUserAdmin();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);

      if (isAdmin) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminPanelPage()),
          (_) => false,
        );
      } else {
        _closeScreenSafely();
      }
    });
  }

  void _closeScreenSafely() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        // LoginSignupScreen is the root of the stack (e.g. after logout).
        // Replace the whole stack with HomeScreen.
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    phoneCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Center(
        child: SingleChildScrollView(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(25),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                )
              ],
            ),
            child: Column(
              children: [
                // App Logo
                Hero(
                  tag: "app_logo",
                  child: Image.asset(
                    "web/icons/virundhu.png",
                    height: 85,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  isLogin ? "Welcome Back!" : "Create an Account",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 20),

                // Signup-only fields
                if (!isLogin) ...[
                  _buildTextField(Icons.person, "Full Name",
                      controller: nameCtrl,
                      keyboardType: TextInputType.name),
                  const SizedBox(height: 15),
                ],

                // Email
                _buildTextField(Icons.email, "Email", controller: emailCtrl),
                const SizedBox(height: 15),

                // Password
                _buildTextField(Icons.lock, "Password",
                    isPassword: true, controller: passwordCtrl),

                if (!isLogin) ...[
                  const SizedBox(height: 15),
                  _buildTextField(Icons.phone, "Phone Number",
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone),
                ],

                const SizedBox(height: 25),

                // -----------------------------------------------------------------
                // LOGIN / SIGN UP BUTTON (Main)
                // -----------------------------------------------------------------
                GestureDetector(
                  onTap: () async {
                    if (_isLoading) return;
                    final email = emailCtrl.text.trim();
                    final password = passwordCtrl.text.trim();
                    if (email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter email and password'),
                        ),
                      );
                      return;
                    }
                    setState(() => _isLoading = true);
                    try {
                      if (isLogin) {
                        await AuthService.login(email, password);
                      } else {
                        await AuthService.signUp(
                          email,
                          password,
                          fullName: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                        );
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isLogin
                                ? 'Login Successful'
                                : 'Account Created Successfully'),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                        await _routeAfterAuth();
                      }
                    } on AuthException catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.message),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade300,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isLogin ? "LOGIN" : "SIGN UP",
                              style: const TextStyle(
                                fontSize: 18,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // OR Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade400)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR"),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade400)),
                  ],
                ),

                const SizedBox(height: 18),

                // Google Login
                GestureDetector(
                  onTap: _isGoogleLoading
                      ? null
                      : () async {
                          setState(() => _isGoogleLoading = true);
                          try {
                            await AuthService.signInWithGoogle();
                            // Navigation handled by auth state listener
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isGoogleLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Google sign-in failed: $e'),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _isGoogleLoading
                        ? const Center(
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              FaIcon(FontAwesomeIcons.google, size: 20),
                              SizedBox(width: 10),
                              Text(
                                "Continue with Google",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                // Switch Login / Signup
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: Text(
                    isLogin
                        ? "Don't have an account? Sign Up"
                        : "Already have an account? Login",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Forgot password (login mode only)
                if (isLogin)
                  GestureDetector(
                    onTap: () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter your email first'),
                          ),
                        );
                        return;
                      }
                      try {
                        await Supabase.instance.client.auth
                            .resetPasswordForEmail(
                          email,
                          redirectTo:
                              'io.supabase.virundhu://reset-callback/',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Password reset email sent!'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Input Field Widget
  // -----------------------------------------------------------------
  Widget _buildTextField(
    IconData icon,
    String hint, {
    bool isPassword = false,
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: hint == 'Email'
            ? TextInputType.emailAddress
            : keyboardType,
        textCapitalization: hint == 'Full Name'
            ? TextCapitalization.words
            : TextCapitalization.none,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(icon, color: Colors.red.shade700),
          hintText: hint,
        ),
      ),
    );
  }
}
