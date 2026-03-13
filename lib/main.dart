import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://nmemvuwtaauftqkdvirw.supabase.co',
    anonKey: 'sb_publishable_mu9z6y-z7v8bRb90WA_uQQ_rVWfpHRG',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virundhu Restaurant App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Define a clean, modern color scheme
        primarySwatch: Colors.red,
        fontFamily: 'Roboto', // Use a modern font family
      ),
      // Set the initial route to the LoadingScreen
      home: const LoadingScreen(), 
    );
  }
}