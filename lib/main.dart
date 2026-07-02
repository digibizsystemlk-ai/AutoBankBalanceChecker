import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/auth_screen.dart';

void main() {
  runApp(const ProviderScope(child: AutoBankBalanceApp()));
}

class AutoBankBalanceApp extends StatelessWidget {
  const AutoBankBalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Bank Balance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}
