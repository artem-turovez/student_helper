import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../admin/admin_home_screen.dart';
import '../student/student_home_screen.dart';
import '../teacher/teacher_home_screen.dart';
import 'start_screen.dart';
import 'verify_email_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _startScreenFuture;

  @override
  void initState() {
    super.initState();

    _startScreenFuture = determineStartScreen();
  }

  Future<Widget> determineStartScreen() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const StartScreen();
    }

    try {
      await user.reload();

      final User? refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        return const StartScreen();
      }

      debugPrint('Проверка автоматического входа');
      debugPrint('UID: ${refreshedUser.uid}');
      debugPrint(
        'Email подтверждён: '
        '${refreshedUser.emailVerified}',
      );

      if (!refreshedUser.emailVerified) {
        return const VerifyEmailScreen();
      }

      await refreshedUser.getIdToken(true);

      debugPrint(
        'Firebase ID token обновлён '
        'перед загрузкой Firestore',
      );

      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();

      if (!userDocument.exists) {
        debugPrint(
          'Профиль пользователя в '
          'Firestore не найден',
        );

        await FirebaseAuth.instance.signOut();

        return const StartScreen();
      }

      final Map<String, dynamic>? userData = userDocument.data();

      if (userData == null) {
        debugPrint(
          'Профиль пользователя '
          'не содержит данных',
        );

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

        case 'admin':
          return const AdminHomeScreen();

        case 'teacher':
          return const TeacherHomeScreen();

        default:
          debugPrint(
            'Неизвестная роль '
            'пользователя: $role',
          );

          await FirebaseAuth.instance.signOut();

          return const StartScreen();
      }
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Firebase Auth ошибка '
        'автоматического входа: '
        '${error.code} - ${error.message}',
      );

      if (error.code == 'network-request-failed') {
        return _AuthConnectionErrorScreen(onRetry: _retry);
      }

      return _AuthConnectionErrorScreen(onRetry: _retry);
    } on FirebaseException catch (error) {
      debugPrint(
        'Firestore ошибка '
        'автоматического входа: '
        '${error.code} - ${error.message}',
      );

      return _AuthConnectionErrorScreen(onRetry: _retry);
    } catch (error) {
      debugPrint(
        'Ошибка автоматического входа: '
        '$error',
      );

      return _AuthConnectionErrorScreen(onRetry: _retry);
    }
  }

  void _retry() {
    if (!mounted) {
      return;
    }

    setState(() {
      _startScreenFuture = determineStartScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _startScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.hasError) {
          return _AuthConnectionErrorScreen(onRetry: _retry);
        }

        return snapshot.data ?? const StartScreen();
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  AppBrand.collegeShortName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 30),
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 14),
                const Text('Загрузка...', style: AppTheme.secondaryBodyText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthConnectionErrorScreen extends StatelessWidget {
  const _AuthConnectionErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
              vertical: 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppBrand.logoPath,
                  width: 110,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 34,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Нет соединения',
                  textAlign: TextAlign.center,
                  style: AppTheme.pageTitle,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Не удалось проверить '
                  'данные аккаунта. '
                  'Проверьте подключение '
                  'к интернету и попробуйте '
                  'ещё раз.',
                  textAlign: TextAlign.center,
                  style: AppTheme.secondaryBodyText,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
