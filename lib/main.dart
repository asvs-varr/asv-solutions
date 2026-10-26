import 'package:flutter/material.dart';
import 'domain/banaag_auth_service.dart';
import 'domain/security_engine.dart';
import 'presentation/theme/banaag_theme.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BanaagAuthService.instance.initialize();
  await SecurityEngine.instance.initialize();
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

