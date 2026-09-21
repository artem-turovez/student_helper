import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

class ForgotPasswordScreen
    extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController =
      TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      debugPrint(
        'Письмо для сброса пароля отправлено: '
        '${emailController.text.trim()}',
      );

      if (!mounted) {
        return;
      }

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Письмо отправлено',
            ),
            content: Text(
              'Мы отправили инструкции для '
              'восстановления пароля на\n\n'
              '${emailController.text.trim()}',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop();
                },
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size(0, 44),
                ),
                child: const Text(
                  'Хорошо',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Password reset error: '
        '${e.code} - ${e.message}',
      );

      String message;

      switch (e.code) {
        case 'invalid-email':
          message =
              'Введите корректный Email';
          break;

        case 'user-not-found':
          message =
              'Пользователь с таким Email '
              'не найден';
          break;

        case 'too-many-requests':
          message =
              'Слишком много запросов. '
              'Попробуйте позже';
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      debugPrint(
        'Неизвестная ошибка восстановления '
        'пароля: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Произошла неизвестная ошибка',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Восстановление пароля',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            28,
            AppTheme.screenPadding,
            32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue
                          .withValues(
                        alpha: 0.15,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_reset_outlined,
                      size: 34,
                      color:
                          AppTheme.primaryBlue,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                const Center(
                  child: Text(
                    'Забыли пароль?',
                    textAlign:
                        TextAlign.center,
                    style:
                        AppTheme.pageTitle,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Введите Email, который '
                  'использовали при регистрации '
                  'в системе МРК. Мы отправим '
                  'инструкции для восстановления.',
                  textAlign: TextAlign.center,
                  style:
                      AppTheme.secondaryBodyText,
                ),

                const SizedBox(height: 32),

                const Text(
                  'Email',
                  style: AppTheme.cardTitle,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction:
                      TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) {
                    if (!isLoading) {
                      resetPassword();
                    }
                  },
                  decoration:
                      const InputDecoration(
                    hintText:
                        'example@mail.com',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Введите Email';
                    }

                    final String email =
                        value.trim();

                    final RegExp emailRegExp =
                        RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    );

                    if (!emailRegExp
                        .hasMatch(email)) {
                      return 'Введите корректный Email';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : resetPassword,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .send_outlined,
                          ),
                    label: Text(
                      isLoading
                          ? 'Отправляем...'
                          : 'Отправить письмо',
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: TextButton.icon(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).pop();
                          },
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 18,
                    ),
                    label: const Text(
                      'Вернуться ко входу',
                    ),
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