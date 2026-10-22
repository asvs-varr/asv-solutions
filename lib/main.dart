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
    return ValueListenableBuilder<BanaagThemeMode>(
      valueListenable: BanaagTheme.currentThemeMode,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'BANAAG - Electrical Project Director',
          debugShowCheckedModeBanner: false,
          theme: BanaagTheme.getTheme(currentMode),
          home: const SplashScreen(),
        );
      },
    );
  }
}

