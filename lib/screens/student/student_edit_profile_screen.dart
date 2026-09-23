import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/public_profile.dart';
import '../../services/public_profile_service.dart';

class StudentEditProfileScreen extends StatefulWidget {
  final PublicProfile profile;

  const StudentEditProfileScreen({super.key, required this.profile});

  @override
  State<StudentEditProfileScreen> createState() =>
      _StudentEditProfileScreenState();
}

class _StudentEditProfileScreenState extends State<StudentEditProfileScreen> {
  final PublicProfileService _profileService = PublicProfileService();

  late final TextEditingController _phoneController;
  late final TextEditingController _telegramController;

  late bool _showEmail;
  late bool _showPhone;
  late bool _showTelegram;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _phoneController = TextEditingController(text: widget.profile.phone ?? '');

    _telegramController = TextEditingController(
      text: widget.profile.telegram ?? '',
    );

    _showEmail = widget.profile.showEmail;
    _showPhone = widget.profile.showPhone;
    _showTelegram = widget.profile.showTelegram;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final String phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return null;
    }

    if (!RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(phone)) {
      return 'Проверьте номер телефона';
    }

    return null;
  }

  String? _validateTelegram(String? value) {
    String telegram = value?.trim() ?? '';

    if (telegram.isEmpty) {
      return null;
    }

    if (telegram.startsWith('@')) {
      telegram = telegram.substring(1);
    }

    if (!RegExp(r'^[A-Za-z0-9_]{5,32}$').hasMatch(telegram)) {
      return 'Введите корректный username Telegram';
    }

    return null;
  }

  String _normalizeTelegram(String value) {
    final String telegram = value.trim();

    if (telegram.isEmpty) {
      return '';
    }

    if (telegram.startsWith('@')) {
      return telegram;
    }

    return '@$telegram';
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final String? phoneError = _validatePhone(_phoneController.text);

    final String? telegramError = _validateTelegram(_telegramController.text);

    if (phoneError != null || telegramError != null) {
      setState(() {});
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Не удалось определить текущего пользователя.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _profileService.updateOwnProfile(
        userId: user.uid,
        phone: _phoneController.text,
        telegram: _normalizeTelegram(_telegramController.text),
        showEmail: _showEmail,
        showPhone: _showPhone,
        showTelegram: _showTelegram,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.code == 'permission-denied') {
        _showMessage('Недостаточно прав для изменения профиля.');
      } else if (error.code == 'unavailable') {
        _showMessage('Нет соединения с сервером. Попробуйте позже.');
      } else {
        _showMessage('Не удалось сохранить профиль.');
      }
    } catch (error) {
      debugPrint('Ошибка сохранения профиля учащегося: $error');

      if (mounted) {
        _showMessage('Не удалось сохранить профиль.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String email =
        FirebaseAuth.instance.currentUser?.email ??
        widget.profile.email ??
        'Не указан';

    return Scaffold(
      appBar: AppBar(title: const Text('Редактирование профиля')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            20,
            AppTheme.screenPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Контактные данные', style: AppTheme.sectionTitle),

              const SizedBox(height: 8),

              const Text(
                'Выберите, какие данные смогут видеть ваши одногруппники.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 20),

              TextFormField(
                initialValue: email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 10),

              _VisibilityCard(
                title: 'Показывать email',
                subtitle: 'Email будет виден другим учащимся вашей группы.',
                value: _showEmail,
                onChanged: (value) {
                  setState(() {
                    _showEmail = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+375 29 000-00-00',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),

              const SizedBox(height: 10),

              _VisibilityCard(
                title: 'Показывать телефон',
                subtitle: 'Номер будет виден другим учащимся вашей группы.',
                value: _showPhone,
                onChanged: (value) {
                  setState(() {
                    _showPhone = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: _telegramController,
                validator: _validateTelegram,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Telegram',
                  hintText: '@username',
                  prefixIcon: Icon(Icons.send_outlined),
                ),
              ),

              const SizedBox(height: 10),

              _VisibilityCard(
                title: 'Показывать Telegram',
                subtitle: 'Telegram будет виден другим учащимся вашей группы.',
                value: _showTelegram,
                onChanged: (value) {
                  setState(() {
                    _showTelegram = value;
                  });
                },
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Сохранить изменения'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _VisibilityCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppTheme.primaryBlue,
        title: Text(title, style: AppTheme.cardTitle),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: AppTheme.secondaryBodyText),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
