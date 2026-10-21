import 'package:flutter/material.dart';
import 'presentation/theme/banaag_theme.dart';
import 'presentation/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BanaagApp());
}

class BanaagApp extends StatelessWidget {
  const BanaagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BANAAG - Electrical Project Director',
      debugShowCheckedModeBanner: false,
      theme: BanaagTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
