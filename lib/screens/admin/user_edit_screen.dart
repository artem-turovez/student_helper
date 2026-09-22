import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/admin_api_service.dart';

class UserEditScreen extends StatefulWidget {
  const UserEditScreen({super.key, required this.user});

  final AdminUser user;

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _groupController;

  late String _role;

  bool _isSaving = false;
  bool _isLoadingTeachers = false;

  String? _teachersError;

  List<AdminTeacher> _teachers = <AdminTeacher>[];

  AdminTeacher? _selectedTeacher;

  bool get _isCurrentUser {
    return FirebaseAuth.instance.currentUser?.uid == widget.user.uid;
  }

  bool get _isCurrentAdmin {
    return _isCurrentUser && widget.user.role == 'admin';
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.user.name ?? '');

    _groupController = TextEditingController(text: widget.user.groupId ?? '');

    final String? currentRole = widget.user.role;

    if (currentRole == 'admin' ||
        currentRole == 'teacher' ||
        currentRole == 'student') {
      _role = currentRole!;
    } else {
      _role = 'student';
    }

    if (_role == 'teacher') {
      _loadTeachers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();

    super.dispose();
  }

  String? _normalizedText(TextEditingController controller) {
    final String value = controller.text.trim();

    return value.isEmpty ? null : value;
  }

  String _roleTitle(String role) {
    switch (role) {
      case 'admin':
        return 'Администратор';
      case 'teacher':
        return 'Преподаватель';
      case 'student':
        return 'Учащийся';
      default:
        return role;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'teacher':
        return Icons.school_rounded;
      case 'student':
        return Icons.person_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  Future<void> _loadTeachers() async {
    if (_isLoadingTeachers) {
      return;
    }

    setState(() {
      _isLoadingTeachers = true;
      _teachersError = null;
    });

    try {
      final List<AdminTeacher> teachers = await AdminApiService.getTeachers();

      if (!mounted) {
        return;
      }

      AdminTeacher? selectedTeacher;

      final String? currentTeacherId = widget.user.teacherId;

      if (currentTeacherId != null && currentTeacherId.isNotEmpty) {
        for (final AdminTeacher teacher in teachers) {
          if (teacher.teacherId == currentTeacherId) {
            selectedTeacher = teacher;
            break;
          }
        }
      }

      setState(() {
        _teachers = teachers;
        _selectedTeacher = selectedTeacher;
        _isLoadingTeachers = false;
      });
    } on AdminApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _teachersError = error.message;
        _isLoadingTeachers = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _teachersError =
            'Не удалось загрузить '
            'преподавателей: $error';

        _isLoadingTeachers = false;
      });
    }
  }

  Future<void> _selectTeacher() async {
    if (_isLoadingTeachers) {
      return;
    }

    if (_teachers.isEmpty) {
      await _loadTeachers();

      if (!mounted || _teachers.isEmpty) {
        return;
      }
    }

    final AdminTeacher? teacher = await showModalBottomSheet<AdminTeacher>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _TeacherSelectorSheet(
          teachers: _teachers,
          selectedTeacherId: _selectedTeacher?.teacherId,
          currentUserUid: widget.user.uid,
          currentTeacherId: widget.user.teacherId,
        );
      },
    );

    if (!mounted || teacher == null) {
      return;
    }

    setState(() {
      _selectedTeacher = teacher;
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String? groupId = _role == 'student'
        ? _normalizedText(_groupController)
        : null;

    final String? teacherId = _role == 'teacher'
        ? _selectedTeacher?.teacherId
        : null;

    if (_role == 'student' && groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Укажите учебную группу '
            'учащегося.',
          ),
        ),
      );

      return;
    }

    if (_role == 'teacher' && teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Выберите преподавателя '
            'для привязки аккаунта.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final AdminUser updatedUser = await AdminApiService.updateUser(
        uid: widget.user.uid,
        name: _normalizedText(_nameController),
        role: _role,
        groupId: groupId,
        teacherId: teacherId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedUser);
    } on AdminApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось сохранить '
            'изменения: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _changeRole(String? value) {
    if (value == null) {
      return;
    }

    setState(() {
      _role = value;

      if (_role != 'teacher') {
        _selectedTeacher = null;
      }
    });

    if (value == 'teacher' && _teachers.isEmpty && !_isLoadingTeachers) {
      _loadTeachers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? email = widget.user.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Редактирование')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          children: [
            _buildUserHeader(),

            const SizedBox(height: 28),

            const Text('Данные пользователя', style: AppTheme.pageTitle),

            const SizedBox(height: 8),

            const Text(
              'Изменения сохраняются '
              'через защищённый сервер '
              'администратора.',
              style: AppTheme.secondaryBodyText,
            ),

            const SizedBox(height: 24),

            const _FieldLabel(text: 'ФИО'),

            const SizedBox(height: 8),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'ФИО пользователя'),
            ),

            const SizedBox(height: 20),

            const _FieldLabel(text: 'Email'),

            const SizedBox(height: 8),

            _ReadOnlyField(
              text: email?.isNotEmpty == true ? email! : 'Не указан',
              icon: Icons.email_outlined,
            ),

            const SizedBox(height: 20),

            const _FieldLabel(text: 'Роль'),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(),
              items: const [
                DropdownMenuItem(value: 'student', child: Text('Учащийся')),
                DropdownMenuItem(
                  value: 'teacher',
                  child: Text('Преподаватель'),
                ),
                DropdownMenuItem(value: 'admin', child: Text('Администратор')),
              ],
              onChanged: _isCurrentAdmin ? null : _changeRole,
            ),

            if (_isCurrentAdmin) ...[
              const SizedBox(height: 8),

              const Text(
                'Роль собственного '
                'административного '
                'аккаунта изменить нельзя.',
                style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
              ),
            ],

            if (_role == 'student') ...[
              const SizedBox(height: 20),

              const _FieldLabel(text: 'Учебная группа'),

              const SizedBox(height: 8),

              TextField(
                controller: _groupController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'Например, 4К9391'),
              ),
            ],

            if (_role == 'teacher') ...[
              const SizedBox(height: 20),

              const _FieldLabel(text: 'Преподаватель'),

              const SizedBox(height: 8),

              _buildTeacherSelector(),
            ],

            const SizedBox(height: 20),

            const _FieldLabel(text: 'UID'),

            const SizedBox(height: 8),

            _ReadOnlyField(
              text: widget.user.uid,
              icon: Icons.fingerprint_rounded,
            ),

            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving
                      ? 'Сохранение...'
                      : 'Сохранить '
                            'изменения',
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherSelector() {
    if (_isLoadingTeachers) {
      return Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Загрузка '
              'преподавателей...',
              style: TextStyle(color: AppTheme.secondaryText),
            ),
          ],
        ),
      );
    }

    if (_teachersError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.secondaryText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _teachersError!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadTeachers,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final AdminTeacher? teacher = _selectedTeacher;

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _selectTeacher,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: teacher == null
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Выбрать '
                            'преподавателя',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryText,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Нажмите, чтобы '
                            'открыть список',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacher.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            teacher.teacherId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryText,
                            ),
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

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _roleIcon(_role),
              color: AppTheme.primaryBlue,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _roleTitle(_role),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
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

class _TeacherSelectorSheet extends StatefulWidget {
  const _TeacherSelectorSheet({
    required this.teachers,
    required this.selectedTeacherId,
    required this.currentUserUid,
    required this.currentTeacherId,
  });

  final List<AdminTeacher> teachers;
  final String? selectedTeacherId;
  final String currentUserUid;
  final String? currentTeacherId;

  @override
  State<_TeacherSelectorSheet> createState() => _TeacherSelectorSheetState();
}

class _TeacherSelectorSheetState extends State<_TeacherSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);

    _searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  bool _isAvailable(AdminTeacher teacher) {
    if (!teacher.linked) {
      return true;
    }

    if (teacher.userUid == widget.currentUserUid) {
      return true;
    }

    if (teacher.teacherId == widget.currentTeacherId) {
      return true;
    }

    return false;
  }

  List<AdminTeacher> get _filteredTeachers {
    final String query = _searchController.text.trim().toLowerCase();

    final List<AdminTeacher> result = widget.teachers.where((
      AdminTeacher teacher,
    ) {
      if (query.isEmpty) {
        return true;
      }

      final String groups = teacher.groupIds.join(' ').toLowerCase();

      final String department = (teacher.department ?? '').toLowerCase();

      return teacher.name.toLowerCase().contains(query) ||
          teacher.teacherId.toLowerCase().contains(query) ||
          groups.contains(query) ||
          department.contains(query);
    }).toList();

    result.sort((AdminTeacher first, AdminTeacher second) {
      final bool firstAvailable = _isAvailable(first);

      final bool secondAvailable = _isAvailable(second);

      if (firstAvailable != secondAvailable) {
        return firstAvailable ? -1 : 1;
      }

      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminTeacher> teachers = _filteredTeachers;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 18),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Выбор '
                        'преподавателя',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText:
                        'Поиск по ФИО '
                        'или группе',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: teachers.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Преподаватели '
                            'не найдены.',
                            textAlign: TextAlign.center,
                            style: AppTheme.secondaryBodyText,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                        itemCount: teachers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final AdminTeacher teacher = teachers[index];

                          final bool available = _isAvailable(teacher);

                          final bool selected =
                              teacher.teacherId == widget.selectedTeacherId;

                          return _TeacherOption(
                            teacher: teacher,
                            available: available,
                            selected: selected,
                            onTap: available
                                ? () {
                                    Navigator.of(context).pop(teacher);
                                  }
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeacherOption extends StatelessWidget {
  const _TeacherOption({
    required this.teacher,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  final AdminTeacher teacher;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primaryBlue.withValues(alpha: 0.10)
          : AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: available ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryText,
                        ),
                      ),

                      if (teacher.groupIds.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          teacher.groupIds.join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],

                      const SizedBox(height: 4),

                      Text(
                        available
                            ? teacher.linked
                                  ? 'Текущая '
                                        'привязка'
                                  : 'Аккаунт '
                                        'не привязан'
                            : 'Уже привязан '
                                  'к другому '
                                  'аккаунту',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: available
                              ? AppTheme.primaryBlue
                              : AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primaryBlue,
                  )
                else
                  Icon(
                    available
                        ? Icons.chevron_right_rounded
                        : Icons.lock_outline_rounded,
                    color: AppTheme.secondaryText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryText,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.secondaryText),

          const SizedBox(width: 10),

          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
