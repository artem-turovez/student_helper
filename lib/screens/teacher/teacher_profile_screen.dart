import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/teacher.dart';
import '../../services/teacher_service.dart';
import '../auth/start_screen.dart';

class TeacherOwnProfileScreen extends StatefulWidget {
  const TeacherOwnProfileScreen({super.key});

  @override
  State<TeacherOwnProfileScreen> createState() =>
      _TeacherOwnProfileScreenState();
}

class _TeacherOwnProfileScreenState extends State<TeacherOwnProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TeacherService _teacherService = TeacherService();

  late Future<_TeacherProfileData?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_TeacherProfileData?> _loadProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> userDocument = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final Map<String, dynamic>? userData = userDocument.data();

    if (userData == null) {
      return null;
    }

    final String teacherId = userData['teacherId']?.toString().trim() ?? '';

    if (teacherId.isEmpty) {
      return _TeacherProfileData(
        teacher: null,
        accountName: userData['name']?.toString() ?? '',
        accountEmail: user.email ?? userData['email']?.toString() ?? '',
        emailVerified: user.emailVerified,
      );
    }

    final Teacher? teacher = await _teacherService.getTeacherById(teacherId);

    return _TeacherProfileData(
      teacher: teacher,
      accountName: userData['name']?.toString() ?? '',
      accountEmail: user.email ?? userData['email']?.toString() ?? '',
      emailVerified: user.emailVerified,
    );
  }

  Future<void> _refreshProfile() async {
    final Future<_TeacherProfileData?> future = _loadProfile();

    setState(() {
      _profileFuture = future;
    });

    await future;
  }

  String _getInitials(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'П';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _displayValue(String value) {
    final String normalized = value.trim();

    if (normalized.isEmpty) {
      return 'Не указано';
    }

    return normalized;
  }

  String _formatGroups(List<String> groupIds) {
    final List<String> groups =
        groupIds
            .map((groupId) => groupId.trim())
            .where((groupId) => groupId.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (groups.isEmpty) {
      return 'Группы пока не назначены';
    }

    return groups.join(', ');
  }

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const StartScreen()),
      (route) => false,
    );
  }

  Future<void> _showLogoutDialog() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          content: const Text(
            'Для следующего входа потребуется '
            'снова ввести email и пароль.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_TeacherProfileData?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ProfileErrorState(onRetry: _refreshProfile);
          }

          final _TeacherProfileData? profile = snapshot.data;

          if (profile == null) {
            return _ProfileErrorState(
              title: 'Профиль не найден',
              description:
                  'Не удалось получить данные '
                  'текущего пользователя.',
              onRetry: _refreshProfile,
            );
          }

          final Teacher? teacher = profile.teacher;

          final String fullName = teacher?.name.trim().isNotEmpty == true
              ? teacher!.name
              : profile.accountName.trim().isNotEmpty
              ? profile.accountName
              : 'Преподаватель';

          final String email = teacher?.email.trim().isNotEmpty == true
              ? teacher!.email
              : profile.accountEmail;

          final String department = teacher?.department ?? '';

          final String phone = teacher?.phone ?? '';

          final String telegram = teacher?.telegram ?? '';

          final List<String> groupIds = teacher?.groupIds ?? const [];

          return RefreshIndicator(
            onRefresh: _refreshProfile,
            color: AppTheme.primaryBlue,
            backgroundColor: AppTheme.card,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                24,
                AppTheme.screenPadding,
                32,
              ),
              children: [
                const Text('Профиль', style: AppTheme.pageTitle),

                const SizedBox(height: 28),

                Center(
                  child: _TeacherProfileAvatar(
                    photoUrl: teacher?.photoUrl,
                    initials: _getInitials(fullName),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Преподаватель',
                  textAlign: TextAlign.center,
                  style: AppTheme.secondaryBodyText,
                ),

                const SizedBox(height: 30),

                const Text('Основная информация', style: AppTheme.sectionTitle),

                const SizedBox(height: 14),

                _TeacherProfileInfoCard(
                  icon: Icons.account_balance_outlined,
                  title: 'Подразделение',
                  value: _displayValue(department),
                ),

                const SizedBox(height: 10),

                _TeacherProfileInfoCard(
                  icon: Icons.groups_outlined,
                  title: 'Учебные группы',
                  value: _formatGroups(groupIds),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Контактная информация',
                  style: AppTheme.sectionTitle,
                ),

                const SizedBox(height: 14),

                _TeacherProfileInfoCard(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: _displayValue(email),
                ),

                const SizedBox(height: 10),

                _TeacherProfileInfoCard(
                  icon: Icons.phone_outlined,
                  title: 'Телефон',
                  value: _displayValue(phone),
                ),

                const SizedBox(height: 10),

                _TeacherProfileInfoCard(
                  icon: Icons.send_outlined,
                  title: 'Telegram',
                  value: _displayValue(telegram),
                ),

                const SizedBox(height: 28),

                const Text('Аккаунт', style: AppTheme.sectionTitle),

                const SizedBox(height: 14),

                const _TeacherProfileInfoCard(
                  icon: Icons.badge_outlined,
                  title: 'Роль',
                  value: 'Преподаватель',
                ),

                const SizedBox(height: 10),

                _TeacherProfileInfoCard(
                  icon: profile.emailVerified
                      ? Icons.verified_outlined
                      : Icons.warning_amber_outlined,
                  title: 'Подтверждение почты',
                  value: profile.emailVerified
                      ? 'Почта подтверждена'
                      : 'Почта не подтверждена',
                  iconColor: profile.emailVerified ? AppTheme.success : null,
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _showLogoutDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(
                        color: AppTheme.danger.withValues(alpha: 0.7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Выйти из аккаунта',
                      style: TextStyle(fontWeight: FontWeight.w600),
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

class _TeacherProfileData {
  final Teacher? teacher;
  final String accountName;
  final String accountEmail;
  final bool emailVerified;

  const _TeacherProfileData({
    required this.teacher,
    required this.accountName,
    required this.accountEmail,
    required this.emailVerified,
  });
}

class _TeacherProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;

  const _TeacherProfileAvatar({required this.photoUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    final String normalizedPhotoUrl = photoUrl?.trim() ?? '';

    if (normalizedPhotoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          normalizedPhotoUrl,
          width: 92,
          height: 92,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsAvatar();
          },
        ),
      );
    }

    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: 92,
      height: 92,
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TeacherProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;

  const _TeacherProfileInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = iconColor ?? AppTheme.primaryBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            ),
            child: Icon(icon, color: color, size: 22),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelText),

                const SizedBox(height: 3),

                SelectableText(value, style: AppTheme.cardTitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  final String title;
  final String description;
  final Future<void> Function() onRetry;

  const _ProfileErrorState({
    this.title = 'Не удалось загрузить профиль',
    this.description =
        'Проверьте подключение к интернету '
        'и повторите попытку.',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 52,
              color: AppTheme.secondaryText,
            ),

            const SizedBox(height: 16),

            Text(title, textAlign: TextAlign.center, style: AppTheme.cardTitle),

            const SizedBox(height: 6),

            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTheme.secondaryBodyText,
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
