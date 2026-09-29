import 'package:flutter/material.dart';
import 'package:numberpick/app/splash_screen.dart';
import 'package:numberpick/features/game/presentation/number_pick_page.dart';

/// Owns app-wide theme selection and the splash-to-game transition.
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _showSplash = true;

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6B6F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6B6F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _showSplash
          ? SplashScreen(
              onFinished: () {
                setState(() {
                  _showSplash = false;
                });
              },
            )
          : NumberPickPage(
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode,
            ),
    );
  }
}
