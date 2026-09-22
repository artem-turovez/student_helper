import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../admin/admin_home_screen.dart';
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

    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      checkEmailVerification();
    });
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
        'Статус подтверждения Email: '
        '${refreshedUser.emailVerified}',
      );

      if (!refreshedUser.emailVerified) {
        return;
      }

      timer?.cancel();

      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();

      if (!userDocument.exists) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль пользователя не найден')),
        );

        return;
      }

      final Map<String, dynamic>? userData = userDocument.data();

      if (userData == null) {
        throw Exception('Не удалось получить данные профиля');
      }

      final String? role = userData['role'] as String?;

      debugPrint(
        'Email подтверждён. '
        'Роль пользователя: $role',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email успешно подтверждён')),
      );

      switch (role) {
        case 'student':
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const StudentHomeScreen()),
            (route) => false,
          );

          return;

        case 'admin':
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
            (route) => false,
          );

          return;

        case 'teacher':
          await FirebaseAuth.instance.signOut();

          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email подтверждён. '
                'Интерфейс преподавателя '
                'будет добавлен позже',
              ),
            ),
          );

          Navigator.of(context).popUntil((route) => route.isFirst);

          return;

        default:
          await FirebaseAuth.instance.signOut();

          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Неизвестная роль пользователя')),
          );

          Navigator.of(context).popUntil((route) => route.isFirst);

          return;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Ошибка проверки Email: '
        '${e.code} - ${e.message}',
      );

      if (!mounted) {
        return;
      }

      if (e.code == 'network-request-failed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось проверить Email. '
              'Проверьте интернет',
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      debugPrint(
        'Ошибка загрузки профиля: '
        '${e.code} - ${e.message}',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось загрузить профиль: '
            '${e.code}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Неизвестная ошибка проверки Email: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось завершить '
            'подтверждение Email',
          ),
        ),
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

      if (user.emailVerified) {
        await checkEmailVerification();
        return;
      }

      await user.sendEmailVerification();

      debugPrint(
        'Письмо подтверждения '
        'отправлено повторно',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Письмо отправлено повторно')),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Ошибка повторной отправки: '
        '${e.code} - ${e.message}',
      );

      String message;

      switch (e.code) {
        case 'too-many-requests':
          message =
              'Слишком много запросов. '
              'Попробуйте немного позже';
          break;

        case 'network-request-failed':
          message =
              'Не удалось подключиться к '
              'серверу. Проверьте интернет';
          break;

        default:
          message =
              'Не удалось отправить письмо. '
              'Ошибка: ${e.code}';
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint(
        'Неизвестная ошибка повторной '
        'отправки: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Произошла неизвестная ошибка')),
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

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подтверждение почты'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            28,
            AppTheme.screenPadding,
            32,
          ),
          child: Column(
            children: [
              Image.asset(
                AppBrand.logoPath,
                width: 90,
                height: 66,
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
                  Icons.mark_email_unread_outlined,
                  size: 34,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Подтвердите почту',
                textAlign: TextAlign.center,
                style: AppTheme.pageTitle,
              ),

              const SizedBox(height: 10),

              const Text(
                'Мы отправили письмо с '
                'подтверждением для доступа '
                'к Помощнику учащегося МРК.',
                textAlign: TextAlign.center,
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppTheme.smallRadius,
                        ),
                      ),
                      child: const Icon(
                        Icons.email_outlined,
                        color: AppTheme.primaryBlue,
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Письмо отправлено на',
                            style: AppTheme.labelText,
                          ),

                          const SizedBox(height: 3),

                          Text(
                            user?.email ?? 'Email не указан',
                            style: AppTheme.cardTitle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Откройте письмо и перейдите '
                'по ссылке подтверждения. '
                'Приложение автоматически '
                'проверит статус.',
                textAlign: TextAlign.center,
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),

                    SizedBox(width: 14),

                    Text(
                      'Ожидаем подтверждение...',
                      style: AppTheme.secondaryBodyText,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: checkEmailVerification,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Я подтвердил почту'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: isSending ? null : resendVerificationEmail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Отправить письмо ещё раз'),
                ),
              ),

              const SizedBox(height: 14),

              TextButton.icon(
                onPressed: logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Выйти из аккаунта'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
