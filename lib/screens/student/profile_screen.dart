import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../auth/start_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  Future<Map<String, dynamic>?> loadUserData() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>>
        document =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    return document.data();
  }

  String getRoleName(String? role) {
    switch (role) {
      case 'student':
        return 'Учащийся';

      case 'teacher':
        return 'Преподаватель';

      case 'admin':
        return 'Администратор';

      default:
        return 'Не указана';
    }
  }

  String getInitials(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (part) => part.isNotEmpty,
        )
        .toList();

    if (parts.isEmpty) {
      return 'У';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'
        .toUpperCase();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) =>
            const StartScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> showLogoutDialog() async {
    final bool? shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Выйти из аккаунта?',
          ),
          content: const Text(
            'Для следующего входа потребуется снова ввести email и пароль.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Отмена',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size(0, 44),
              ),
              child: const Text(
                'Выйти',
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? firebaseUser =
        FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: FutureBuilder<Map<String, dynamic>?>(
        future: loadUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Не удалось загрузить профиль',
                style:
                    AppTheme.secondaryBodyText,
              ),
            );
          }

          final Map<String, dynamic>? data =
              snapshot.data;

          final String fullName =
              data?['name']?.toString() ??
                  'Пользователь';

          final String email =
              firebaseUser?.email ??
                  data?['email']?.toString() ??
                  'Не указан';

          final String role = getRoleName(
            data?['role']?.toString(),
          );

          final String? groupId =
              data?['groupId']?.toString();

          final bool emailVerified =
              firebaseUser?.emailVerified ??
                  false;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              24,
              AppTheme.screenPadding,
              32,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Профиль',
                  style: AppTheme.pageTitle,
                ),

                const SizedBox(height: 28),

                Center(
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration:
                        const BoxDecoration(
                      color:
                          AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      getInitials(fullName),
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight:
                            FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: Text(
                    fullName,
                    textAlign:
                        TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          AppTheme.primaryText,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Center(
                  child: Text(
                    role,
                    style: AppTheme
                        .secondaryBodyText,
                  ),
                ),

                const SizedBox(height: 30),

                ProfileInfoCard(
                  icon:
                      Icons.email_outlined,
                  title: 'Email',
                  value: email,
                ),

                const SizedBox(height: 10),

                ProfileInfoCard(
                  icon:
                      Icons.school_outlined,
                  title: 'Учебная группа',
                  value: groupId == null ||
                          groupId.trim().isEmpty
                      ? 'Группа пока не назначена'
                      : groupId,
                ),

                const SizedBox(height: 10),

                ProfileInfoCard(
                  icon:
                      Icons.badge_outlined,
                  title: 'Роль',
                  value: role,
                ),

                const SizedBox(height: 10),

                ProfileInfoCard(
                  icon: emailVerified
                      ? Icons
                          .verified_outlined
                      : Icons
                          .warning_amber_outlined,
                  title:
                      'Подтверждение почты',
                  value: emailVerified
                      ? 'Почта подтверждена'
                      : 'Почта не подтверждена',
                  iconColor: emailVerified
                      ? AppTheme.success
                      : null,
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed:
                        showLogoutDialog,
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          AppTheme.danger,
                      side: BorderSide(
                        color: AppTheme.danger
                            .withValues(
                          alpha: 0.7,
                        ),
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.logout,
                    ),
                    label: const Text(
                      'Выйти из аккаунта',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;

  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        iconColor ?? AppTheme.primaryBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(
                AppTheme.smallRadius,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      AppTheme.labelText,
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style:
                      AppTheme.cardTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}