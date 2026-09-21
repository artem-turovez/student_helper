import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../student/student_home_screen.dart';
import 'start_screen.dart';
import 'verify_email_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
  });

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Widget>
      determineStartScreen() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const StartScreen();
    }

    try {
      await user.reload();

      final User? refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        return const StartScreen();
      }

      if (!refreshedUser.emailVerified) {
        return const VerifyEmailScreen();
      }

      final DocumentSnapshot<Map<String, dynamic>>
          userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();

      if (!userDocument.exists) {
        await FirebaseAuth.instance.signOut();

        return const StartScreen();
      }

      final Map<String, dynamic>? userData =
          userDocument.data();

      if (userData == null) {
        await FirebaseAuth.instance.signOut();

        return const StartScreen();
      }

      final String? role =
          userData['role'] as String?;

      debugPrint(
        'Автоматический вход',
      );
      debugPrint(
        'UID: ${refreshedUser.uid}',
      );
      debugPrint(
        'Роль: $role',
      );

      switch (role) {
        case 'student':
          return const StudentHomeScreen();

        case 'teacher':
          return const StartScreen();

        case 'admin':
          return const StartScreen();

        default:
          await FirebaseAuth.instance
              .signOut();

          return const StartScreen();
      }
    } catch (e) {
      debugPrint(
        'Ошибка автоматического входа: $e',
      );

      return const StartScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: determineStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.hasError) {
          return const StartScreen();
        }

        return snapshot.data ??
            const StartScreen();
      },
    );
  }
}

class _AuthLoadingScreen
    extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal:
                  AppTheme.screenPadding,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Image.asset(
                  AppBrand.logoPath,
                  width: 130,
                  height: 95,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 26),

                const Text(
                  AppBrand.appName,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        AppTheme.primaryText,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  AppBrand.collegeShortName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                    color: AppTheme
                        .secondaryText,
                  ),
                ),

                const SizedBox(height: 30),

                const SizedBox(
                  width: 30,
                  height: 30,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Загрузка...',
                  style: AppTheme
                      .secondaryBodyText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}