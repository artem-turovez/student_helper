import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../student/student_home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? timer;

  bool isChecking = false;
  bool isSending = false;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        checkEmailVerification();
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerification() async {
    if (isChecking) {
      return;
    }

    isChecking = true;

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await user.reload();

      final User? refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        return;
      }

      debugPrint(
        'Статус подтверждения Email: ${refreshedUser.emailVerified}',
      );

      if (refreshedUser.emailVerified) {
        timer?.cancel();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email успешно подтверждён',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const StudentHomeScreen(),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Ошибка проверки Email: ${e.code} - ${e.message}',
      );
    } catch (e) {
      debugPrint(
        'Неизвестная ошибка проверки Email: $e',
      );
    } finally {
      isChecking = false;
    }
  }

  Future<void> resendVerificationEmail() async {
    if (isSending) {
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await user.sendEmailVerification();

      debugPrint(
        'Письмо подтверждения отправлено повторно',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Письмо отправлено повторно',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Ошибка повторной отправки: ${e.code} - ${e.message}',
      );

      String message;

      switch (e.code) {
        case 'too-many-requests':
          message =
              'Слишком много запросов. Попробуйте немного позже';
          break;

        case 'network-request-failed':
          message =
              'Не удалось подключиться к серверу. Проверьте интернет';
          break;

        default:
          message =
              'Не удалось отправить письмо. Ошибка: ${e.code}';
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint(
        'Неизвестная ошибка повторной отправки: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Произошла неизвестная ошибка',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> logout() async {
    timer?.cancel();

    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF07142B),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Подтверждение Email',
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              const Icon(
                Icons.mark_email_unread_outlined,
                size: 90,
                color: Color(0xFF2B7FFF),
              ),

              const SizedBox(height: 32),

              const Text(
                'Подтвердите почту',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Мы отправили письмо с подтверждением на:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFB6C5E0),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                user?.email ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Откройте письмо и перейдите по ссылке подтверждения. '
                'После этого приложение автоматически проверит статус '
                'и откроет главную страницу.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFB6C5E0),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              const CircularProgressIndicator(),

              const SizedBox(height: 12),

              const Text(
                'Ожидаем подтверждение...',
                style: TextStyle(
                  color: Color(0xFFB6C5E0),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: isSending
                      ? null
                      : resendVerificationEmail,
                  child: isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Отправить письмо ещё раз',
                        ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: logout,
                child: const Text(
                  'Выйти из аккаунта',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}