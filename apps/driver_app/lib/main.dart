import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF2F5F1),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const CargooDriverApp());
}

class CargooDriverApp extends StatelessWidget {
  const CargooDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CARGOO Dereva',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F5F1),
        primaryColor: const Color(0xFF4B7B9F),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4B7B9F),
          secondary: Color(0xFF16A34A),
          surface: Colors.white,
          error: Color(0xFFEF4444),
        ),
        fontFamily: 'Segoe UI Variable',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1E2822)),
          titleTextStyle: TextStyle(color: Color(0xFF1E2822), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
