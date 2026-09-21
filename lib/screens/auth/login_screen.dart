import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import '../student/student_home_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool isPasswordVisible = false;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception(
          'Firebase не вернул пользователя',
        );
      }

      await user.reload();

      final User? refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        throw Exception(
          'Не удалось получить пользователя',
        );
      }

      debugPrint('Вход выполнен');
      debugPrint('UID: ${refreshedUser.uid}');
      debugPrint(
        'Email: ${refreshedUser.email}',
      );
      debugPrint(
        'Email подтверждён: '
        '${refreshedUser.emailVerified}',
      );

      if (!mounted) {
        return;
      }

      if (!refreshedUser.emailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                const VerifyEmailScreen(),
          ),
        );

        return;
      }

      final DocumentSnapshot<Map<String, dynamic>>
          userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();

      if (!userDocument.exists) {
        throw Exception(
          'Профиль пользователя не найден',
        );
      }

      final Map<String, dynamic>? userData =
          userDocument.data();

      if (userData == null) {
        throw Exception(
          'Не удалось получить данные профиля',
        );
      }

      final String? role =
          userData['role'] as String?;

      debugPrint(
        'Роль пользователя: $role',
      );

      if (!mounted) {
        return;
      }

      switch (role) {
        case 'student':
          Navigator.of(context)
              .pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  const StudentHomeScreen(),
            ),
            (route) => false,
          );
          break;

        case 'teacher':
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Интерфейс преподавателя '
                'будет добавлен позже',
              ),
            ),
          );
          break;

        case 'admin':
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Интерфейс администратора '
                'будет добавлен позже',
              ),
            ),
          );
          break;

        default:
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Неизвестная роль пользователя',
              ),
            ),
          );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuth login error: '
        '${e.code} - ${e.message}',
      );

      String message;

      switch (e.code) {
        case 'invalid-email':
          message =
              'Введите корректный Email';
          break;

        case 'user-disabled':
          message =
              'Этот аккаунт заблокирован';
          break;

        case 'user-not-found':
          message =
              'Пользователь с таким Email '
              'не найден';
          break;

        case 'wrong-password':
          message = 'Неверный пароль';
          break;

        case 'invalid-credential':
          message =
              'Неверный Email или пароль';
          break;

        case 'too-many-requests':
          message =
              'Слишком много попыток. '
              'Попробуйте позже';
          break;

        case 'network-request-failed':
          message =
              'Не удалось подключиться к '
              'серверу. Проверьте интернет';
          break;

        default:
          message =
              'Не удалось войти. '
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
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore login error: '
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
      debugPrint(
        'Неизвестная ошибка входа: $e',
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
        title: const Text('Вход'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            20,
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
                  child: Image.asset(
                    AppBrand.logoPath,
                    width: 92,
                    height: 68,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'С возвращением!',
                  style: AppTheme.pageTitle,
                ),

                const SizedBox(height: 8),

                const Text(
                  'Войдите в Помощник учащегося '
                  'Минского радиотехнического колледжа.',
                  style:
                      AppTheme.secondaryBodyText,
                ),

                const SizedBox(height: 30),

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
                      TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
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

                const SizedBox(height: 20),

                const Text(
                  'Пароль',
                  style: AppTheme.cardTitle,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      passwordController,
                  obscureText:
                      !isPasswordVisible,
                  textInputAction:
                      TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) {
                    if (!isLoading) {
                      loginUser();
                    }
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Введите пароль',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          isPasswordVisible =
                              !isPasswordVisible;
                        });
                      },
                      icon: Icon(
                        isPasswordVisible
                            ? Icons
                                .visibility_off_outlined
                            : Icons
                                .visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Введите пароль';
                    }

                    if (value.length < 8) {
                      return 'Пароль должен содержать '
                          'минимум 8 символов';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 6),

                Align(
                  alignment:
                      Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const ForgotPasswordScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      'Забыли пароль?',
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLoading
                        ? null
                        : loginUser,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Войти',
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Нет аккаунта?',
                      style: AppTheme
                          .secondaryBodyText,
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        'Создать',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}