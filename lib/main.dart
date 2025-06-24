import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'screens/home_screen.dart';

void main() {
  // 在Linux/Windows/macOS桌面环境中初始化sqflite
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
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
