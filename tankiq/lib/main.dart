import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TankIQApp());
}

class TankIQApp extends StatelessWidget {
  const TankIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TankIQ',
      theme: ThemeData(

        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101524), // Dark Blue Background
        cardColor: const Color(0xFF1C2438), // Lighter Blue for Cards
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF27E26), // Orange
          onPrimary: Colors.white,
          secondary: Color(0xFFF27E26),
          surface: Color(0xFF1C2438),
          onSurface: Colors.white,
          background: Color(0xFF101524),
          onBackground: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101524),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF27E26),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C2438),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF27E26), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white60),
          hintStyle: const TextStyle(color: Colors.white30),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF101524),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: const HomeScreen(),
      localizationsDelegates: const [
        // Add localization delegates later for full Spanish support if needed
      ],
    );
  }
}
