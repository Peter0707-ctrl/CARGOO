import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable full edge-to-edge rendering so app extends behind system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );

  // Custom Error Boundary: Never expose raw code, exceptions, or line numbers to users
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF2F5F1),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF4B7B9F),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2822),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A temporary issue occurred. Please try again or restart the application.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Segoe UI Variable',
                  fontSize: 13,
                  color: Color(0xFF6B7E74),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const CargooCustomerApp());
}

class CargooCustomerApp extends StatelessWidget {
  const CargooCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CARGOO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF2F5F1),
        fontFamily: 'Segoe UI Variable',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4B7B9F),
          primary: const Color(0xFF4B7B9F),
          surface: const Color(0xFFF2F5F1),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
