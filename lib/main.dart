import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CorgiReciteApp());
}

class CorgiReciteApp extends StatelessWidget {
  const CorgiReciteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corgi Recite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
