import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/teacher.dart';
import '../../services/profile_photo_service.dart';
import '../../services/teacher_service.dart';

class TeacherEditProfileScreen extends StatefulWidget {
  final Teacher teacher;

  const TeacherEditProfileScreen({super.key, required this.teacher});

  @override
  State<TeacherEditProfileScreen> createState() =>
      _TeacherEditProfileScreenState();
}

class _TeacherEditProfileScreenState extends State<TeacherEditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TeacherService _teacherService = TeacherService();

  final ProfilePhotoService _photoService = ProfilePhotoService();

  late final TextEditingController _departmentController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _telegramController;

  late bool _showEmail;
  late bool _showPhone;
  late bool _showTelegram;

  late String? _photoUrl;

  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();

    _departmentController = TextEditingController(
      text: widget.teacher.department,
    );

    _emailController = TextEditingController(text: widget.teacher.email);

    _phoneController = TextEditingController(text: widget.teacher.phone);

    _telegramController = TextEditingController(text: widget.teacher.telegram);

    _showEmail = widget.teacher.showEmail;
    _showPhone = widget.teacher.showPhone;
    _showTelegram = widget.teacher.showTelegram;

    _photoUrl = widget.teacher.photoUrl;
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _telegramController.dispose();

    super.dispose();
  }

  String get _initials {
    final List<String> parts = widget.teacher.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return null;
    }

    final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      return 'Введите корректный email';
    }

    return null;
  }

  Future<void> _changePhoto() async {
    if (_isUploadingPhoto || _isSaving) {
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final String? photoUrl = await _photoService.pickAndUploadPhoto();

      if (!mounted) {
        return;
      }

      if (photoUrl == null) {
        return;
      }

      setState(() {
        _photoUrl = photoUrl;
      });

      _showMessage('Фотография профиля обновлена');
    } catch (error) {
      debugPrint(
        'Ошибка загрузки фото '
        'преподавателя: $error',
      );

      if (!mounted) {
        return;
      }

      _showMessage(_photoErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  String _photoErrorMessage(Object error) {
    final String message = error.toString();

    if (message.contains('Слишком большой файл')) {
      return 'Фотография слишком большая.';
    }

    if (message.contains('Недопустимый формат')) {
      return 'Этот формат изображения '
          'не поддерживается.';
    }

    if (message.contains('не авторизован')) {
      return 'Не удалось подтвердить '
          'авторизацию.';
    }

    if (message.contains('преподавател')) {
      return message.replaceFirst('Exception: ', '');
    }

    return 'Не удалось загрузить '
        'фотографию. Попробуйте ещё раз.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_isSaving || _isUploadingPhoto) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      await _teacherService.updateOwnProfile(
        teacherId: widget.teacher.id,
        email: _emailController.text,
        phone: _phoneController.text,
        telegram: _telegramController.text,
        department: _departmentController.text,
        showEmail: _showEmail,
        showPhone: _showPhone,
        showTelegram: _showTelegram,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Профиль успешно обновлён');

      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint(
        'Ошибка сохранения профиля '
        'преподавателя: $error',
      );

      if (!mounted) {
        return;
      }

      _showMessage('Не удалось сохранить изменения');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Редактирование профиля')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              20,
              AppTheme.screenPadding,
              32,
            ),
            children: [
              const Text('Фотография профиля', style: AppTheme.sectionTitle),

              const SizedBox(height: 8),

              const Text(
                'Фотография будет видна '
                'учащимся и другим '
                'преподавателям в разделе '
                '«Контакты».',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 18),

              Center(
                child: _ProfilePhoto(photoUrl: _photoUrl, initials: _initials),
              ),

              const SizedBox(height: 14),

              Center(
                child: OutlinedButton.icon(
                  onPressed: _isUploadingPhoto || _isSaving
                      ? null
                      : _changePhoto,
                  icon: _isUploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _isUploadingPhoto
                        ? 'Загрузка...'
                        : _photoUrl?.trim().isNotEmpty == true
                        ? 'Изменить фото'
                        : 'Добавить фото',
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const Text('Основная информация', style: AppTheme.sectionTitle),

              const SizedBox(height: 14),

              _ReadOnlyField(
                label: 'ФИО',
                value: widget.teacher.name,
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 12),

              _EditField(
                controller: _departmentController,
                label: 'Подразделение',
                hint: 'Например, отделение информатики',
                icon: Icons.account_balance_outlined,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 28),

              const Text('Контактная информация', style: AppTheme.sectionTitle),

              const SizedBox(height: 6),

              const Text(
                'Эти данные используются '
                'в разделе «Контакты». '
                'Вы можете самостоятельно '
                'выбрать, какие из них '
                'будут видны другим.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 16),

              _EditField(
                controller: _emailController,
                label: 'Контактный email',
                hint: 'example@mail.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
              ),

              const SizedBox(height: 12),

              _EditField(
                controller: _phoneController,
                label: 'Телефон',
                hint: '+375 29 000-00-00',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 12),

              _EditField(
                controller: _telegramController,
                label: 'Telegram',
                hint: '@username',
                icon: Icons.send_outlined,
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 28),

              const Text('Видимость контактов', style: AppTheme.sectionTitle),

              const SizedBox(height: 6),

              const Text(
                'Отключённые контакты '
                'не будут показываться '
                'учащимся и другим '
                'преподавателям.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 14),

              _VisibilityCard(
                icon: Icons.email_outlined,
                title: 'Показывать email',
                description:
                    'Контактный email будет '
                    'виден в вашем профиле.',
                value: _showEmail,
                onChanged: (value) {
                  setState(() {
                    _showEmail = value;
                  });
                },
              ),

              const SizedBox(height: 10),

              _VisibilityCard(
                icon: Icons.phone_outlined,
                title: 'Показывать телефон',
                description:
                    'Номер телефона будет '
                    'доступен в вашем профиле.',
                value: _showPhone,
                onChanged: (value) {
                  setState(() {
                    _showPhone = value;
                  });
                },
              ),

              const SizedBox(height: 10),

              _VisibilityCard(
                icon: Icons.send_outlined,
                title: 'Показывать Telegram',
                description:
                    'Telegram будет доступен '
                    'в вашем профиле.',
                value: _showTelegram,
                onChanged: (value) {
                  setState(() {
                    _showTelegram = value;
                  });
                },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving || _isUploadingPhoto ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Сохранение...' : 'Сохранить изменения',
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

class _ProfilePhoto extends StatelessWidget {
  final String? photoUrl;
  final String initials;

  const _ProfilePhoto({required this.photoUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    final String normalizedUrl = photoUrl?.trim() ?? '';

    if (normalizedUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          normalizedUrl,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _InitialsPhoto(initials: initials);
          },
        ),
      );
    }

    return _InitialsPhoto(initials: initials);
  }
}

class _InitialsPhoto extends StatelessWidget {
  final String initials;

  const _InitialsPhoto({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const _EditField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.labelText),

                const SizedBox(height: 3),

                Text(value, style: AppTheme.cardTitle),

                const SizedBox(height: 3),

                const Text(
                  'Изменяется администратором',
                  style: AppTheme.secondaryBodyText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _VisibilityCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        secondary: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
          ),
          child: Icon(icon, size: 21, color: AppTheme.primaryBlue),
        ),
        title: Text(title, style: AppTheme.cardTitle),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(description, style: AppTheme.secondaryBodyText),
        ),
      ),
    );
  }
}
