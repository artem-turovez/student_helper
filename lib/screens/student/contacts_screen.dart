import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/public_profile.dart';
import '../../models/teacher.dart';
import '../../services/public_profile_service.dart';
import '../../services/teacher_service.dart';
import 'contact_profile_screen.dart';
import 'teacher_profile_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final PublicProfileService _publicProfileService = PublicProfileService();
  final TeacherService _teacherService = TeacherService();

  List<PublicProfile> _classmates = [];
  List<Teacher> _teachers = [];

  bool _isLoading = true;
  bool _classmatesHasError = false;
  bool _teachersHasError = false;
  bool _groupIsNotAssigned = false;

  int _selectedList = 0;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _classmatesHasError = false;
        _teachersHasError = false;
        _groupIsNotAssigned = false;
      });
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('Контакты: пользователь не авторизован');

      if (!mounted) {
        return;
      }

      setState(() {
        _classmates = [];
        _teachers = [];
        _classmatesHasError = true;
        _teachersHasError = true;
        _isLoading = false;
      });

      return;
    }

    String? groupId;

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDocument.exists) {
        throw Exception('Профиль пользователя не найден');
      }

      final Map<String, dynamic>? userData = userDocument.data();

      groupId = userData?['groupId']?.toString().trim();

      debugPrint('Контакты: UID = ${user.uid}');
      debugPrint('Контакты: groupId = $groupId');
    } catch (error) {
      debugPrint('Контакты: ошибка загрузки users/${user.uid}: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _classmates = [];
        _teachers = [];
        _classmatesHasError = true;
        _teachersHasError = true;
        _isLoading = false;
      });

      return;
    }

    if (groupId == null || groupId.isEmpty) {
      debugPrint('Контакты: учебная группа пользователю не назначена');

      if (!mounted) {
        return;
      }

      setState(() {
        _classmates = [];
        _teachers = [];
        _groupIsNotAssigned = true;
        _isLoading = false;
      });

      return;
    }

    List<PublicProfile> classmates = [];
    List<Teacher> teachers = [];

    bool classmatesHasError = false;
    bool teachersHasError = false;

    try {
      debugPrint('Контакты: запрос publicProfiles для группы $groupId...');

      classmates = await _publicProfileService.getClassmates(
        groupId: groupId,
        currentUserId: user.uid,
      );

      debugPrint(
        'Контакты: publicProfiles успешно, найдено одногруппников: '
        '${classmates.length}',
      );
    } catch (error) {
      classmatesHasError = true;

      debugPrint('Контакты: ОШИБКА publicProfiles: $error');
    }

    try {
      debugPrint('Контакты: запрос teachers для группы $groupId...');

      teachers = await _teacherService.getTeachersForGroup(groupId);

      debugPrint(
        'Контакты: teachers успешно, найдено преподавателей: '
        '${teachers.length}',
      );
    } catch (error) {
      teachersHasError = true;

      debugPrint('Контакты: ОШИБКА teachers: $error');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _classmates = classmates;
      _teachers = teachers;
      _classmatesHasError = classmatesHasError;
      _teachersHasError = teachersHasError;
      _isLoading = false;
    });
  }

  void _openClassmateProfile(PublicProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContactProfileScreen(profile: profile),
      ),
    );
  }

  void _openTeacherProfile(Teacher teacher) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeacherProfileScreen(teacher: teacher),
      ),
    );
  }

  void _selectList(int index) {
    setState(() {
      _selectedList = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadContacts,
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
            const Text('Контакты', style: AppTheme.pageTitle),
            const SizedBox(height: 24),
            _ContactsSwitcher(
              selectedIndex: _selectedList,
              onSelected: _selectList,
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _selectedList == 0 ? _buildClassmates() : _buildTeachers(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassmates() {
    if (_isLoading) {
      return const _LoadingCard(key: ValueKey('classmates-loading'));
    }

    if (_groupIsNotAssigned) {
      return const _MessageCard(
        key: ValueKey('classmates-no-group'),
        icon: Icons.hourglass_empty_rounded,
        text: 'Учебная группа ещё не назначена. После проверки администратор назначит вашу группу.',
      );
    }

    if (_classmatesHasError) {
      return const _MessageCard(
        key: ValueKey('classmates-error'),
        icon: Icons.error_outline,
        text: 'Не удалось загрузить одногруппников',
      );
    }

    if (_classmates.isEmpty) {
      return const _MessageCard(
        key: ValueKey('classmates-empty'),
        icon: Icons.group_outlined,
        text: 'Одногруппники пока не найдены',
      );
    }

    return Column(
      key: const ValueKey('classmates'),
      children: _classmates.map((profile) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ContactListItem(
            name: profile.name,
            icon: Icons.person_outline,
            onTap: () => _openClassmateProfile(profile),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTeachers() {
    if (_isLoading) {
      return const _LoadingCard(key: ValueKey('teachers-loading'));
    }

    if (_groupIsNotAssigned) {
      return const _MessageCard(
        key: ValueKey('teachers-no-group'),
        icon: Icons.hourglass_empty_rounded,
        text: 'Учебная группа ещё не назначена. После проверки администратор назначит вашу группу.',
      );
    }

    if (_teachersHasError) {
      return const _MessageCard(
        key: ValueKey('teachers-error'),
        icon: Icons.error_outline,
        text: 'Не удалось загрузить преподавателей',
      );
    }

    if (_teachers.isEmpty) {
      return const _MessageCard(
        key: ValueKey('teachers-empty'),
        icon: Icons.school_outlined,
        text: 'Преподаватели для вашей группы пока не найдены',
      );
    }

    return Column(
      key: const ValueKey('teachers'),
      children: _teachers.map((teacher) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TeacherListItem(
            teacher: teacher,
            onTap: () => _openTeacherProfile(teacher),
          ),
        );
      }).toList(),
    );
  }
}

class _ContactsSwitcher extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ContactsSwitcher({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitcherButton(
              title: 'Одногруппники',
              icon: Icons.group_outlined,
              isSelected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SwitcherButton(
              title: 'Преподаватели',
              icon: Icons.school_outlined,
              isSelected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitcherButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SwitcherButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppTheme.secondaryText,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactListItem extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  const _ContactListItem({
    required this.name,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                ),
                child: Icon(icon, size: 22, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(name, style: AppTheme.cardTitle)),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherListItem extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback onTap;

  const _TeacherListItem({required this.teacher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _TeacherAvatar(teacher: teacher),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacher.name, style: AppTheme.cardTitle),
                    if (teacher.department.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        teacher.department,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.secondaryBodyText,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  final Teacher teacher;

  const _TeacherAvatar({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = teacher.photoUrl;

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        child: Image.network(
          photoUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      ),
      child: const Icon(
        Icons.school_outlined,
        size: 22,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MessageCard({super.key, required this.icon, required this.text});

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
            child: Icon(icon, size: 22, color: AppTheme.secondaryText),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: AppTheme.secondaryBodyText)),
        ],
      ),
    );
  }
}
