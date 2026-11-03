import 'package:flutter/material.dart';

import 'camera_page.dart';

///// Block 1: App entry point ////////////////////////////////////////////////

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FrogEasyCameraApp());
}

///// Block 2: Standalone camera app //////////////////////////////////////////

class FrogEasyCameraApp extends StatelessWidget {
  const FrogEasyCameraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Frog Easy Camera',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D32),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    home: const EasyCameraPage(),
  );
}
