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
  late final TextEditingController _teacherController;

  late String _role;

  bool _isSaving = false;

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

    _teacherController = TextEditingController(
      text: widget.user.teacherId ?? '',
    );

    final String? currentRole = widget.user.role;

    if (currentRole == 'admin' ||
        currentRole == 'teacher' ||
        currentRole == 'student') {
      _role = currentRole!;
    } else {
      _role = 'student';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _teacherController.dispose();

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

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String? groupId = _role == 'student'
        ? _normalizedText(_groupController)
        : null;

    final String? teacherId = _role == 'teacher'
        ? _normalizedText(_teacherController)
        : null;

    if (_role == 'student' && groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите учебную группу учащегося.')),
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

            _FieldLabel(text: 'ФИО'),

            const SizedBox(height: 8),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'ФИО пользователя'),
            ),

            const SizedBox(height: 20),

            _FieldLabel(text: 'Email'),

            const SizedBox(height: 8),

            _ReadOnlyField(
              text: email?.isNotEmpty == true ? email! : 'Не указан',
              icon: Icons.email_outlined,
            ),

            const SizedBox(height: 20),

            _FieldLabel(text: 'Роль'),

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
              onChanged: _isCurrentAdmin
                  ? null
                  : (String? value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _role = value;
                      });
                    },
            ),

            if (_isCurrentAdmin) ...[
              const SizedBox(height: 8),

              const Text(
                'Роль собственного '
                'административного аккаунта '
                'изменить нельзя.',
                style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
              ),
            ],

            if (_role == 'student') ...[
              const SizedBox(height: 20),

              _FieldLabel(text: 'Учебная группа'),

              const SizedBox(height: 8),

              TextField(
                controller: _groupController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'Например, 4К9391'),
              ),
            ],

            if (_role == 'teacher') ...[
              const SizedBox(height: 20),

              _FieldLabel(text: 'ID преподавателя'),

              const SizedBox(height: 8),

              TextField(
                controller: _teacherController,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'ID документа преподавателя',
                ),
              ),
            ],

            const SizedBox(height: 20),

            _FieldLabel(text: 'UID'),

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
                  _isSaving ? 'Сохранение...' : 'Сохранить изменения',
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
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
