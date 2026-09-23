import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/lesson.dart';
import '../../models/public_profile.dart';
import '../../models/teacher.dart';
import '../../services/public_profile_service.dart';
import '../../services/schedule_service.dart';
import '../../services/teacher_service.dart';
import '../student/contact_profile_screen.dart';
import '../student/teacher_profile_screen.dart';

class TeacherContactsScreen extends StatefulWidget {
  const TeacherContactsScreen({super.key});

  @override
  State<TeacherContactsScreen> createState() => _TeacherContactsScreenState();
}

class _TeacherContactsScreenState extends State<TeacherContactsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ScheduleService _scheduleService = ScheduleService();

  final PublicProfileService _publicProfileService = PublicProfileService();

  final TeacherService _teacherService = TeacherService();

  int _selectedList = 0;

  bool _isLoading = true;
  bool _hasError = false;

  List<PublicProfile> _students = [];
  List<Teacher> _teachers = [];
  List<String> _groupIds = [];

  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDocument.exists) {
        throw Exception('Профиль преподавателя не найден');
      }

      final Map<String, dynamic>? userData = userDocument.data();

      final String teacherId = userData?['teacherId']?.toString().trim() ?? '';

      if (teacherId.isEmpty) {
        throw Exception('Преподаватель не назначен');
      }

      final List<Lesson> lessons = await _scheduleService.getLessonsForTeacher(
        teacherId: teacherId,
      );

      final Set<String> groupIds = lessons
          .map((lesson) => lesson.groupId?.trim() ?? '')
          .where((groupId) => groupId.isNotEmpty)
          .toSet();

      final List<String> sortedGroupIds = groupIds.toList()..sort();

      final List<dynamic> results = await Future.wait<dynamic>([
        _publicProfileService.getStudentsForGroups(groupIds: sortedGroupIds),
        _teacherService.getAllTeachers(excludeTeacherId: teacherId),
      ]);

      final List<PublicProfile> students = results[0] as List<PublicProfile>;

      final List<Teacher> teachers = results[1] as List<Teacher>;

      if (!mounted) {
        return;
      }

      setState(() {
        _students = students;
        _teachers = teachers;
        _groupIds = sortedGroupIds;

        if (_selectedGroupId != null && !_groupIds.contains(_selectedGroupId)) {
          _selectedGroupId = null;
        }

        _isLoading = false;
        _hasError = false;
      });
    } catch (error) {
      debugPrint('Ошибка загрузки контактов преподавателя: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _students = [];
        _teachers = [];
        _groupIds = [];
        _selectedGroupId = null;

        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _selectList(int index) {
    setState(() {
      _selectedList = index;

      if (index != 0) {
        _selectedGroupId = null;
      }
    });
  }

  void _selectGroup(String groupId) {
    setState(() {
      _selectedGroupId = groupId;
    });
  }

  void _closeGroup() {
    setState(() {
      _selectedGroupId = null;
    });
  }

  void _openStudentProfile(PublicProfile profile) {
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
              child: _selectedList == 0
                  ? _buildStudentsSection()
                  : _buildTeachers(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsSection() {
    if (_isLoading) {
      return const _LoadingCard(key: ValueKey('students-loading'));
    }

    if (_hasError) {
      return const _MessageCard(
        key: ValueKey('students-error'),
        icon: Icons.error_outline,
        text: 'Не удалось загрузить студентов',
      );
    }

    if (_groupIds.isEmpty) {
      return const _MessageCard(
        key: ValueKey('groups-empty'),
        icon: Icons.groups_outlined,
        text: 'В расписании преподавателя пока нет учебных групп',
      );
    }

    final String? selectedGroupId = _selectedGroupId;

    if (selectedGroupId == null) {
      return _buildGroups();
    }

    return _buildStudentsForGroup(selectedGroupId);
  }

  Widget _buildGroups() {
    return Column(
      key: const ValueKey('groups'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Учебные группы', style: AppTheme.sectionTitle),

        const SizedBox(height: 12),

        ..._groupIds.map((groupId) {
          final int studentCount = _students
              .where((profile) => profile.groupId?.trim() == groupId)
              .length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GroupListItem(
              groupId: groupId,
              studentCount: studentCount,
              onTap: () => _selectGroup(groupId),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStudentsForGroup(String groupId) {
    final List<PublicProfile> groupStudents = _students
        .where((profile) => profile.groupId?.trim() == groupId)
        .toList();

    return Column(
      key: ValueKey('group-$groupId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupHeader(groupId: groupId, onBack: _closeGroup),

        const SizedBox(height: 16),

        if (groupStudents.isEmpty)
          const _MessageCard(
            icon: Icons.person_search_outlined,
            text: 'В этой группе студенты пока не найдены',
          )
        else
          ...groupStudents.map((profile) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudentListItem(
                profile: profile,
                onTap: () => _openStudentProfile(profile),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTeachers() {
    if (_isLoading) {
      return const _LoadingCard(key: ValueKey('teachers-loading'));
    }

    if (_hasError) {
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
        text: 'Другие преподаватели пока не найдены',
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
              title: 'Студенты',
              icon: Icons.groups_outlined,
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

class _GroupListItem extends StatelessWidget {
  final String groupId;
  final int studentCount;
  final VoidCallback onTap;

  const _GroupListItem({
    required this.groupId,
    required this.studentCount,
    required this.onTap,
  });

  String _studentCountText() {
    final int lastTwoDigits = studentCount % 100;

    final int lastDigit = studentCount % 10;

    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) {
      return '$studentCount студентов';
    }

    if (lastDigit == 1) {
      return '$studentCount студент';
    }

    if (lastDigit >= 2 && lastDigit <= 4) {
      return '$studentCount студента';
    }

    return '$studentCount студентов';
  }

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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  size: 23,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(groupId, style: AppTheme.cardTitle),

                    const SizedBox(height: 4),

                    Text(
                      _studentCountText(),
                      style: AppTheme.secondaryBodyText,
                    ),
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

class _GroupHeader extends StatelessWidget {
  final String groupId;
  final VoidCallback onBack;

  const _GroupHeader({required this.groupId, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 21,
                color: AppTheme.primaryText,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Группа $groupId', style: AppTheme.sectionTitle),

              const SizedBox(height: 3),

              const Text('Студенты группы', style: AppTheme.secondaryBodyText),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentListItem extends StatelessWidget {
  final PublicProfile profile;
  final VoidCallback onTap;

  const _StudentListItem({required this.profile, required this.onTap});

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
              _StudentAvatar(profile: profile),

              const SizedBox(width: 14),

              Expanded(child: Text(profile.name, style: AppTheme.cardTitle)),

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

class _StudentAvatar extends StatelessWidget {
  final PublicProfile profile;

  const _StudentAvatar({required this.profile});

  String _getInitials() {
    final List<String> parts = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'С';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = profile.photoUrl;

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
      alignment: Alignment.center,
      child: Text(
        _getInitials(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
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
