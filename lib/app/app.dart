import 'package:flutter/material.dart';

import '../screens/auth/auth_gate.dart';
import 'theme.dart';

class StudentHelperApp extends StatelessWidget {
  const StudentHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Помощник учащегося',
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}