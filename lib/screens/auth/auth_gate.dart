import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../student/student_home_screen.dart';
import 'start_screen.dart';
import 'verify_email_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Widget> determineStartScreen() async {
    final User? user = FirebaseAuth.instance.currentUser;

    // Пользователь не авторизован.
    if (user == null) {
      return const StartScreen();
    }

    try {
      // Получаем актуальные данные пользователя из Firebase.
      await user.reload();

      final User? refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        return const StartScreen();
      }

      // Пользователь есть, но Email ещё не подтверждён.
      if (!refreshedUser.emailVerified) {
        return const VerifyEmailScreen();
      }

      // Получаем профиль пользователя из Firestore.
      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();

      if (!userDocument.exists) {
        await FirebaseAuth.instance.signOut();

        return const StartScreen();
      }

      final Map<String, dynamic>? userData = userDocument.data();

      if (userData == null) {
        await FirebaseAuth.instance.signOut();

        return const StartScreen();
      }

      final String? role = userData['role'] as String?;

      debugPrint('Автоматический вход');
      debugPrint('UID: ${refreshedUser.uid}');
      debugPrint('Роль: $role');

      switch (role) {
        case 'student':
          return const StudentHomeScreen();

        case 'teacher':
          // Интерфейс преподавателя сделаем позже.
          return const StartScreen();

        case 'admin':
          // Интерфейс администратора сделаем позже.
          return const StartScreen();

        default:
          await FirebaseAuth.instance.signOut();

          return const StartScreen();
      }
    } catch (e) {
      debugPrint('Ошибка автоматического входа: $e');

      return const StartScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: determineStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const StartScreen();
        }

        return snapshot.data ?? const StartScreen();
      },
    );
  }
}