import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/start_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?> loadUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final document = await FirebaseFirestore.instance
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
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'У';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const StartScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> showLogoutDialog() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
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
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Отмена',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
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
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    return FutureBuilder<Map<String, dynamic>?>(
      future: loadUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Не удалось загрузить профиль',
            ),
          );
        }

        final Map<String, dynamic>? data = snapshot.data;

        final String fullName =
            data?['name']?.toString() ?? 'Пользователь';

        final String email =
            firebaseUser?.email ??
            data?['email']?.toString() ??
            'Не указан';

        final String role =
            getRoleName(data?['role']?.toString());

        final String? groupId =
            data?['groupId']?.toString();

        final bool emailVerified =
            firebaseUser?.emailVerified ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              const Text(
                'Профиль',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFF2B7FFF),
                  child: Text(
                    getInitials(fullName),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Center(
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFB6C5E0),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              ProfileInfoCard(
                icon: Icons.email_outlined,
                title: 'Email',
                value: email,
              ),

              const SizedBox(height: 12),

              ProfileInfoCard(
                icon: Icons.school_outlined,
                title: 'Учебная группа',
                value: groupId ?? 'Группа пока не назначена',
              ),

              const SizedBox(height: 12),

              ProfileInfoCard(
                icon: Icons.badge_outlined,
                title: 'Роль',
                value: role,
              ),

              const SizedBox(height: 12),

              ProfileInfoCard(
                icon: emailVerified
                    ? Icons.verified_outlined
                    : Icons.warning_amber_outlined,
                title: 'Подтверждение почты',
                value: emailVerified
                    ? 'Почта подтверждена'
                    : 'Почта не подтверждена',
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: showLogoutDialog,
                  icon: const Icon(
                    Icons.logout,
                  ),
                  label: const Text(
                    'Выйти из аккаунта',
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10213D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2B7FFF).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2B7FFF),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB6C5E0),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}