import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/admin_api_service.dart';

class UserCreateScreen extends StatefulWidget {
  const UserCreateScreen({super.key});

  @override
  State<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends State<UserCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();

  String _role = 'student';

  bool _isSaving = false;
  bool _isLoadingTeachers = false;
  bool _passwordVisible = false;

  String? _teachersError;

  List<AdminTeacher> _teachers = const [];
  AdminTeacher? _selectedTeacher;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _groupController.dispose();

    super.dispose();
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

      setState(() {
        _teachers = teachers;
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
        _teachersError = 'Не удалось загрузить преподавателей: $error';
        _isLoadingTeachers = false;
      });
    }
  }

  Future<void> _selectTeacher() async {
    if (_teachers.isEmpty && !_isLoadingTeachers) {
      await _loadTeachers();
    }

    if (!mounted) {
      return;
    }

    if (_teachersError != null && _teachers.isEmpty) {
      _showMessage(_teachersError!);
      return;
    }

    final AdminTeacher? teacher = await showModalBottomSheet<AdminTeacher>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _TeacherSelectorSheet(
          teachers: _teachers,
          selectedTeacherId: _selectedTeacher?.teacherId,
        );
      },
    );

    if (teacher == null || !mounted) {
      return;
    }

    setState(() {
      _selectedTeacher = teacher;
    });
  }

  void _changeRole(String? role) {
    if (role == null) {
      return;
    }

    setState(() {
      _role = role;

      if (_role != 'teacher') {
        _selectedTeacher = null;
      }
    });

    if (role == 'teacher' && _teachers.isEmpty && !_isLoadingTeachers) {
      _loadTeachers();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _looksLikeEmail(String value) {
    final int atIndex = value.indexOf('@');

    if (atIndex <= 0) {
      return false;
    }

    if (atIndex != value.lastIndexOf('@')) {
      return false;
    }

    final String domain = value.substring(atIndex + 1);

    return domain.contains('.') &&
        !domain.startsWith('.') &&
        !domain.endsWith('.');
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text;
    final String groupId = _groupController.text.trim();

    if (name.isEmpty) {
      _showMessage('Введите ФИО пользователя.');
      return;
    }

    if (email.isEmpty) {
      _showMessage('Введите email пользователя.');
      return;
    }

    if (!_looksLikeEmail(email)) {
      _showMessage('Введите корректный email.');
      return;
    }

    if (password.length < 6) {
      _showMessage('Пароль должен содержать не менее 6 символов.');
      return;
    }

    if (_role == 'student' && groupId.isEmpty) {
      _showMessage('Укажите учебную группу.');
      return;
    }

    if (_role == 'teacher' && _selectedTeacher == null) {
      _showMessage('Выберите преподавателя.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final AdminUser createdUser = await AdminApiService.createUser(
        name: name,
        email: email,
        password: password,
        role: _role,
        groupId: _role == 'student' ? groupId : null,
        teacherId: _role == 'teacher' ? _selectedTeacher!.teacherId : null,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(createdUser);
    } on AdminApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);

      setState(() {
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Не удалось создать пользователя: $error');

      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildTeacherField() {
    final AdminTeacher? teacher = _selectedTeacher;

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isSaving ? null : _selectTeacher,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              const Icon(
                Icons.school_rounded,
                size: 20,
                color: AppTheme.secondaryText,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher?.name ?? 'Выберите преподавателя',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: teacher == null
                            ? FontWeight.w500
                            : FontWeight.w600,
                        color: teacher == null
                            ? AppTheme.secondaryText
                            : AppTheme.primaryText,
                      ),
                    ),

                    if (teacher != null) ...[
                      const SizedBox(height: 4),

                      Text(
                        teacher.teacherId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (_isLoadingTeachers)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый пользователь')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Создание аккаунта', style: AppTheme.pageTitle),

              const SizedBox(height: 8),

              const Text(
                'Аккаунт будет создан в Firebase Authentication '
                'и добавлен в базу пользователей.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 28),

              const _FieldLabel(text: 'ФИО'),

              const SizedBox(height: 8),

              TextField(
                controller: _nameController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  hint: 'Введите ФИО пользователя',
                  icon: Icons.person_outline_rounded,
                ),
              ),

              const SizedBox(height: 20),

              const _FieldLabel(text: 'Email'),

              const SizedBox(height: 8),

              TextField(
                controller: _emailController,
                enabled: !_isSaving,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  hint: 'example@mail.com',
                  icon: Icons.email_outlined,
                ),
              ),

              const SizedBox(height: 20),

              const _FieldLabel(text: 'Временный пароль'),

              const SizedBox(height: 8),

              TextField(
                controller: _passwordController,
                enabled: !_isSaving,
                obscureText: !_passwordVisible,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  hint: 'Не менее 6 символов',
                  icon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Пароль используется только для создания аккаунта '
                'и не сохраняется в Firestore.',
                style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),

              const SizedBox(height: 20),

              const _FieldLabel(text: 'Роль'),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: _inputDecoration(
                  hint: 'Выберите роль',
                  icon: Icons.badge_outlined,
                ),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Учащийся')),
                  DropdownMenuItem(
                    value: 'teacher',
                    child: Text('Преподаватель'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Администратор'),
                  ),
                ],
                onChanged: _isSaving ? null : _changeRole,
              ),

              if (_role == 'student') ...[
                const SizedBox(height: 20),

                const _FieldLabel(text: 'Учебная группа'),

                const SizedBox(height: 8),

                TextField(
                  controller: _groupController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration(
                    hint: 'Например, 4К9391',
                    icon: Icons.groups_rounded,
                  ),
                ),
              ],

              if (_role == 'teacher') ...[
                const SizedBox(height: 20),

                const _FieldLabel(text: 'Преподаватель'),

                const SizedBox(height: 8),

                _buildTeacherField(),

                if (_teachersError != null) ...[
                  const SizedBox(height: 8),

                  Text(
                    _teachersError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(
                    _isSaving ? 'Создание...' : 'Создать пользователя',
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherSelectorSheet extends StatefulWidget {
  const _TeacherSelectorSheet({
    required this.teachers,
    required this.selectedTeacherId,
  });

  final List<AdminTeacher> teachers;
  final String? selectedTeacherId;

  @override
  State<_TeacherSelectorSheet> createState() => _TeacherSelectorSheetState();
}

class _TeacherSelectorSheetState extends State<_TeacherSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  List<AdminTeacher> get _filteredTeachers {
    final String query = _query.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.teachers;
    }

    return widget.teachers.where((AdminTeacher teacher) {
      final String groups = teacher.groupIds.join(' ');

      final String searchable = [
        teacher.name,
        teacher.teacherId,
        teacher.department ?? '',
        groups,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      hintText: 'Поиск по ФИО, ID или группе',
      prefixIcon: const Icon(Icons.search_rounded),
      filled: true,
      fillColor: AppTheme.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminTeacher> teachers = _filteredTeachers;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выберите преподавателя',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryText,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Преподаватели, уже связанные с аккаунтом, '
                      'недоступны для выбора.',
                      style: AppTheme.secondaryBodyText,
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _searchController,
                      onChanged: (String value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      decoration: _searchDecoration(),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: teachers.isEmpty
                    ? const Center(
                        child: Text(
                          'Ничего не найдено',
                          style: AppTheme.secondaryBodyText,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: teachers.length,
                        itemBuilder: (BuildContext context, int index) {
                          final AdminTeacher teacher = teachers[index];

                          final bool selected =
                              teacher.teacherId == widget.selectedTeacherId;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TeacherCard(
                              teacher: teacher,
                              selected: selected,
                            ),
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

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher, required this.selected});

  final AdminTeacher teacher;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bool available = !teacher.linked;

    final String groups = teacher.groupIds.isEmpty
        ? 'Группы не указаны'
        : teacher.groupIds.join(', ');

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: available
            ? () {
                Navigator.of(context).pop(teacher);
              }
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: available ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    Icons.school_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                ),

                const SizedBox(width: 14),

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

                      const SizedBox(height: 5),

                      Text(
                        groups,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryText,
                        ),
                      ),

                      if (teacher.department != null) ...[
                        const SizedBox(height: 4),

                        Text(
                          teacher.department!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),

                      Text(
                        available
                            ? 'Доступен для привязки'
                            : 'Уже привязан к аккаунту',
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
