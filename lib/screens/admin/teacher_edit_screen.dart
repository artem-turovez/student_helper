import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/admin_api_service.dart';

class TeacherEditScreen extends StatefulWidget {
  const TeacherEditScreen({super.key, required this.teacher});

  final AdminTeacher teacher;

  @override
  State<TeacherEditScreen> createState() => _TeacherEditScreenState();
}

class _TeacherEditScreenState extends State<TeacherEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _telegramController;
  late final TextEditingController _departmentController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.teacher.name);

    _emailController = TextEditingController(text: widget.teacher.email ?? '');

    _phoneController = TextEditingController(text: widget.teacher.phone ?? '');

    _telegramController = TextEditingController(
      text: widget.teacher.telegram ?? '',
    );

    _departmentController = TextEditingController(
      text: widget.teacher.department ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _telegramController.dispose();
    _departmentController.dispose();

    super.dispose();
  }

  String? _optionalValue(TextEditingController controller) {
    final String value = controller.text.trim();

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите ФИО преподавателя.')),
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final AdminTeacher updatedTeacher = await AdminApiService.updateTeacher(
        teacherId: widget.teacher.teacherId,
        name: name,
        email: _optionalValue(_emailController),
        phone: _optionalValue(_phoneController),
        telegram: _optionalValue(_telegramController),
        department: _optionalValue(_departmentController),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedTeacher);
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
        SnackBar(content: Text('Не удалось сохранить преподавателя: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminTeacher teacher = widget.teacher;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Преподаватель')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              title: 'Основная информация',
              children: [
                _EditableField(
                  controller: _nameController,
                  label: 'ФИО',
                  hintText: 'ФИО преподавателя',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _EditableField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'example@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _EditableField(
                  controller: _phoneController,
                  label: 'Телефон',
                  hintText: '+375...',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _EditableField(
                  controller: _telegramController,
                  label: 'Telegram',
                  hintText: '@username',
                  icon: Icons.send_rounded,
                ),
                const SizedBox(height: 16),
                _EditableField(
                  controller: _departmentController,
                  label: 'Отделение / кафедра',
                  hintText: 'Не указано',
                  icon: Icons.apartment_rounded,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Системная информация',
              children: [
                _ReadOnlyField(
                  label: 'ID преподавателя',
                  value: teacher.teacherId,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),
                _ReadOnlyField(
                  label: 'Группы',
                  value: teacher.groupIds.isEmpty
                      ? 'Группы не указаны'
                      : teacher.groupIds.join(', '),
                  icon: Icons.groups_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AccountCard(teacher: teacher),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Сохранение...' : 'Сохранить'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: AppTheme.secondaryText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.teacher});

  final AdminTeacher teacher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Аккаунт',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: teacher.linked
                      ? AppTheme.primaryBlue.withValues(alpha: 0.10)
                      : AppTheme.secondaryText.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  teacher.linked ? Icons.link_rounded : Icons.link_off_rounded,
                  color: teacher.linked
                      ? AppTheme.primaryBlue
                      : AppTheme.secondaryText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.linked
                          ? 'Аккаунт привязан'
                          : 'Аккаунт не привязан',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _accountDescription(),
                      style: AppTheme.secondaryBodyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _accountDescription() {
    if (!teacher.linked) {
      return 'Привязка выполняется через управление пользователями.';
    }

    final List<String> parts = [];

    final String? userName = teacher.userName;

    if (userName != null && userName.isNotEmpty) {
      parts.add(userName);
    }

    final String? userEmail = teacher.userEmail;

    if (userEmail != null && userEmail.isNotEmpty) {
      parts.add(userEmail);
    }

    if (parts.isNotEmpty) {
      return parts.join('\n');
    }

    return 'К преподавателю привязан пользователь.';
  }
}
