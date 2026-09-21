import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController
      repeatPasswordController =
      TextEditingController();

  bool isPasswordVisible = false;
  bool isRepeatPasswordVisible = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    repeatPasswordController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
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
              .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final User? user =
          userCredential.user;

      if (user == null) {
        throw Exception(
          'Firebase не вернул пользователя',
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'role': 'student',
        'groupId': null,
        'teacherId': null,
        'createdAt':
            FieldValue.serverTimestamp(),
      });

      await user.sendEmailVerification();

      debugPrint(
        'Пользователь успешно создан',
      );
      debugPrint('UID: ${user.uid}');
      debugPrint('Email: ${user.email}');
      debugPrint(
        'Профиль сохранён в Firestore',
      );
      debugPrint(
        'Письмо подтверждения отправлено',
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              const VerifyEmailScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuth error: '
        '${e.code} - ${e.message}',
      );

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'Аккаунт с таким Email '
              'уже существует';
          break;

        case 'invalid-email':
          message =
              'Введите корректный Email';
          break;

        case 'weak-password':
          message =
              'Пароль слишком простой';
          break;

        case 'network-request-failed':
          message =
              'Не удалось подключиться к '
              'серверу. Проверьте интернет';
          break;

        case 'operation-not-allowed':
          message =
              'Регистрация по Email '
              'сейчас недоступна';
          break;

        case 'too-many-requests':
          message =
              'Слишком много попыток. '
              'Попробуйте немного позже';
          break;

        default:
          message =
              'Не удалось зарегистрироваться. '
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
        'Firestore error: '
        '${e.code} - ${e.message}',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось сохранить профиль: '
            '${e.code}',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Неизвестная ошибка регистрации: $e',
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
          'Регистрация',
        ),
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
                  'Создание аккаунта',
                  style: AppTheme.pageTitle,
                ),

                const SizedBox(height: 8),

                const Text(
                  'Зарегистрируйтесь в '
                  'Помощнике учащегося МРК.',
                  style:
                      AppTheme.secondaryBodyText,
                ),

                const SizedBox(height: 30),

                const Text(
                  'ФИО',
                  style: AppTheme.cardTitle,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: nameController,
                  textCapitalization:
                      TextCapitalization.words,
                  textInputAction:
                      TextInputAction.next,
                  decoration:
                      const InputDecoration(
                    hintText:
                        'Иванов Иван Иванович',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Введите ФИО';
                    }

                    if (value.trim().length <
                        5) {
                      return 'Введите полное ФИО';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

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
                      TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    hintText:
                        'Минимум 8 символов',
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
                      return 'Минимальная длина '
                          'пароля — 8 символов';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'Повторите пароль',
                  style: AppTheme.cardTitle,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      repeatPasswordController,
                  obscureText:
                      !isRepeatPasswordVisible,
                  textInputAction:
                      TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) {
                    if (!isLoading) {
                      registerUser();
                    }
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Введите пароль ещё раз',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          isRepeatPasswordVisible =
                              !isRepeatPasswordVisible;
                        });
                      },
                      icon: Icon(
                        isRepeatPasswordVisible
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
                      return 'Повторите пароль';
                    }

                    if (value !=
                        passwordController.text) {
                      return 'Пароли не совпадают';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLoading
                        ? null
                        : registerUser,
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
                            'Создать аккаунт',
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Уже есть аккаунт?',
                      style: AppTheme
                          .secondaryBodyText,
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pop();
                            },
                      child:
                          const Text('Войти'),
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