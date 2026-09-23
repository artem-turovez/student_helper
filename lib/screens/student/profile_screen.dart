import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/public_profile.dart';
import '../../services/public_profile_service.dart';
import '../auth/start_screen.dart';
import 'student_edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final PublicProfileService _publicProfileService = PublicProfileService();

  late Future<_StudentProfileData?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
  }

  Future<_StudentProfileData?> _loadProfileData() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> userDocument =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final Map<String, dynamic>? userData = userDocument.data();

    if (userData == null) {
      return null;
    }

    PublicProfile? publicProfile;

    final String? groupId = userData['groupId']?.toString();

    if (groupId != null && groupId.trim().isNotEmpty) {
      publicProfile = await _publicProfileService.getProfileById(user.uid);
    }

    return _StudentProfileData(
      userData: userData,
      publicProfile: publicProfile,
    );
  }

  void _reloadProfile() {
    setState(() {
      _profileFuture = _loadProfileData();
    });
  }

  String _getRoleName(String? role) {
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

  String _getInitials(String fullName) {
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

  Future<void> _openEditProfile(PublicProfile profile) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StudentEditProfileScreen(profile: profile),
      ),
    );

    if (changed == true && mounted) {
      _reloadProfile();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Профиль успешно обновлён')),
        );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

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
            'Для следующего входа потребуется снова ввести email и пароль.',
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
      child: FutureBuilder<_StudentProfileData?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ProfileErrorState(onRetry: _reloadProfile);
          }

          final _StudentProfileData? profileData = snapshot.data;

          if (profileData == null) {
            return _ProfileErrorState(onRetry: _reloadProfile);
          }

          final User? firebaseUser = FirebaseAuth.instance.currentUser;

          final Map<String, dynamic> data = profileData.userData;

          final PublicProfile? publicProfile = profileData.publicProfile;

          final String fullName =
              data['name']?.toString().trim() ?? 'Пользователь';

          final String email =
              firebaseUser?.email ?? data['email']?.toString() ?? 'Не указан';

          final String role = _getRoleName(data['role']?.toString());

          final String groupId = data['groupId']?.toString().trim() ?? '';

          final bool hasAssignedGroup = groupId.isNotEmpty;

          final bool emailVerified = firebaseUser?.emailVerified ?? false;

          final String phone = publicProfile?.phone?.trim() ?? '';

          final String telegram = publicProfile?.telegram?.trim() ?? '';

          return RefreshIndicator(
            onRefresh: () async {
              _reloadProfile();
              await _profileFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                24,
                AppTheme.screenPadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Профиль', style: AppTheme.pageTitle),

                  const SizedBox(height: 28),

                  Center(
                    child: _ProfileAvatar(
                      fullName: fullName,
                      photoUrl: publicProfile?.photoUrl,
                      initials: _getInitials(fullName),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Center(child: Text(role, style: AppTheme.secondaryBodyText)),

                  const SizedBox(height: 30),

                  const Text(
                    'Основная информация',
                    style: AppTheme.sectionTitle,
                  ),

                  const SizedBox(height: 12),

                  ProfileInfoCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: email,
                  ),

                  const SizedBox(height: 10),

                  ProfileInfoCard(
                    icon: Icons.school_outlined,
                    title: 'Учебная группа',
                    value: hasAssignedGroup
                        ? groupId
                        : 'Группа пока не назначена',
                  ),

                  const SizedBox(height: 10),

                  ProfileInfoCard(
                    icon: Icons.badge_outlined,
                    title: 'Роль',
                    value: role,
                  ),

                  const SizedBox(height: 10),

                  ProfileInfoCard(
                    icon: emailVerified
                        ? Icons.verified_outlined
                        : Icons.warning_amber_outlined,
                    title: 'Подтверждение почты',
                    value: emailVerified
                        ? 'Почта подтверждена'
                        : 'Почта не подтверждена',
                    iconColor: emailVerified
                        ? AppTheme.success
                        : AppTheme.danger,
                  ),

                  const SizedBox(height: 28),

                  const Text('Контактные данные', style: AppTheme.sectionTitle),

                  const SizedBox(height: 12),

                  if (!hasAssignedGroup)
                    const _GroupRequiredCard()
                  else if (publicProfile == null)
                    const _PublicProfileUnavailableCard()
                  else ...[
                    ProfileInfoCard(
                      icon: Icons.phone_outlined,
                      title: 'Телефон',
                      value: phone.isEmpty ? 'Не указан' : phone,
                      trailing: _VisibilityIndicator(
                        isVisible: publicProfile.showPhone,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ProfileInfoCard(
                      icon: Icons.send_outlined,
                      title: 'Telegram',
                      value: telegram.isEmpty ? 'Не указан' : telegram,
                      trailing: _VisibilityIndicator(
                        isVisible: publicProfile.showTelegram,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ProfileInfoCard(
                      icon: Icons.email_outlined,
                      title: 'Видимость email',
                      value: publicProfile.showEmail
                          ? 'Виден одногруппникам'
                          : 'Скрыт от одногруппников',
                      iconColor: publicProfile.showEmail
                          ? AppTheme.success
                          : AppTheme.secondaryText,
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          _openEditProfile(publicProfile);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Редактировать профиль'),
                      ),
                    ),
                  ],

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
            ),
          );
        },
      ),
    );
  }
}

class _StudentProfileData {
  final Map<String, dynamic> userData;
  final PublicProfile? publicProfile;

  const _StudentProfileData({
    required this.userData,
    required this.publicProfile,
  });
}

class _ProfileAvatar extends StatelessWidget {
  final String fullName;
  final String? photoUrl;
  final String initials;

  const _ProfileAvatar({
    required this.fullName,
    required this.photoUrl,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final String normalizedPhotoUrl = photoUrl?.trim() ?? '';

    if (normalizedPhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 46,
        backgroundColor: AppTheme.card,
        backgroundImage: NetworkImage(normalizedPhotoUrl),
      );
    }

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
        semanticsLabel: fullName,
        style: const TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final Widget? trailing;

  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    this.trailing,
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
                Text(value, style: AppTheme.cardTitle),
              ],
            ),
          ),

          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _VisibilityIndicator extends StatelessWidget {
  final bool isVisible;

  const _VisibilityIndicator({required this.isVisible});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isVisible ? 'Видно одногруппникам' : 'Скрыто от одногруппников',
      child: Icon(
        isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 21,
        color: isVisible ? AppTheme.success : AppTheme.secondaryText,
      ),
    );
  }
}

class _GroupRequiredCard extends StatelessWidget {
  const _GroupRequiredCard();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      icon: Icons.hourglass_top_outlined,
      text: 'Учебная группа ещё не назначена. После назначения группы администратором станут доступны контакты и другие функции колледжа.',
    );
  }
}

class _PublicProfileUnavailableCard extends StatelessWidget {
  const _PublicProfileUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      icon: Icons.person_off_outlined,
      text: 'Публичный профиль пока недоступен. Попробуйте обновить страницу позже.',
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppTheme.secondaryText,
            ),
            const SizedBox(height: 14),
            const Text(
              'Не удалось загрузить профиль',
              style: AppTheme.cardTitle,
            ),
            const SizedBox(height: 6),
            const Text(
              'Проверьте подключение к интернету и попробуйте ещё раз.',
              textAlign: TextAlign.center,
              style: AppTheme.secondaryBodyText,
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MessageCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            ),
            child: const Icon(
              Icons.info_outline,
              size: 22,
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: AppTheme.secondaryBodyText)),
        ],
      ),
    );
  }
}
