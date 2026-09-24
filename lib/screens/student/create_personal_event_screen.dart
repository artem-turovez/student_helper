import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/personal_event.dart';
import '../../services/personal_event_service.dart';
import '../../services/notification_service.dart';

class CreatePersonalEventScreen extends StatefulWidget {
  final DateTime initialDate;
  final PersonalEvent? event;

  const CreatePersonalEventScreen({
    super.key,
    required this.initialDate,
    this.event,
  });

  @override
  State<CreatePersonalEventScreen> createState() =>
      _CreatePersonalEventScreenState();
}

class _CreatePersonalEventScreenState extends State<CreatePersonalEventScreen> {
  final PersonalEventService _personalEventService = PersonalEventService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late DateTime _selectedDate;

  int? _reminderMinutesBefore;

  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  static const List<_ReminderOption> _reminderOptions = [
    _ReminderOption(minutes: null, label: 'Не напоминать'),
    _ReminderOption(minutes: 0, label: 'В момент события'),
    _ReminderOption(minutes: 5, label: 'За 5 минут'),
    _ReminderOption(minutes: 15, label: 'За 15 минут'),
    _ReminderOption(minutes: 30, label: 'За 30 минут'),
    _ReminderOption(minutes: 60, label: 'За 1 час'),
    _ReminderOption(minutes: 1440, label: 'За 1 день'),
  ];

  @override
  void initState() {
    super.initState();

    final PersonalEvent? event = widget.event;

    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _selectedDate = event.date;
      _reminderMinutesBefore = event.reminderMinutesBefore;
    } else {
      final DateTime initialDate = widget.initialDate;
      final DateTime now = DateTime.now();

      _selectedDate = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        now.hour,
        now.minute,
      );

      _reminderMinutesBefore = null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        result.year,
        result.month,
        result.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  Future<void> _selectTime() async {
    final TimeOfDay? result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _selectedDate.hour,
        minute: _selectedDate.minute,
      ),
      helpText: 'Выберите время',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        result.hour,
        result.minute,
      );
    });
  }

  Future<void> _saveEvent() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название события')));

      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить пользователя')),
      );

      return;
    }

    final int? reminderMinutesBefore = _reminderMinutesBefore;

    if (reminderMinutesBefore != null) {
      final DateTime reminderDate = _selectedDate.subtract(
        Duration(minutes: reminderMinutesBefore),
      );

      if (!reminderDate.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Время напоминания уже прошло. '
              'Измените время события или напоминание.',
            ),
          ),
        );

        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        final String? eventId = widget.event?.id;

        if (eventId == null) {
          throw Exception('Не удалось определить событие');
        }

        await _personalEventService.updateEvent(
          eventId: eventId,
          title: title,
          description: description,
          date: _selectedDate,
          reminderMinutesBefore: _reminderMinutesBefore,
        );

        await NotificationService.instance.schedulePersonalEventReminder(
          eventId: eventId,
          title: title,
          description: description,
          eventDate: _selectedDate,
          reminderMinutesBefore: _reminderMinutesBefore,
        );
      } else {
        final PersonalEvent event = PersonalEvent(
          userId: user.uid,
          title: title,
          description: description,
          date: _selectedDate,
          reminderMinutesBefore: _reminderMinutesBefore,
        );

        final String eventId = await _personalEventService.createEvent(
          event: event,
        );

        await NotificationService.instance.schedulePersonalEventReminder(
          eventId: eventId,
          title: title,
          description: description,
          eventDate: _selectedDate,
          reminderMinutesBefore: _reminderMinutesBefore,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Ошибка сохранения личного события: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Не удалось сохранить изменения'
                : 'Не удалось создать событие',
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    const List<String> months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _reminderLabel(int? minutes) {
    for (final _ReminderOption option in _reminderOptions) {
      if (option.minutes == minutes) {
        return option.label;
      }
    }

    return 'Не напоминать';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактирование события' : 'Новое событие'),
      ),
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
              Text(
                _isEditing ? 'Измените информацию' : 'Добавьте событие',
                style: AppTheme.pageTitle,
              ),
              const SizedBox(height: 8),
              Text(
                _isEditing
                    ? 'Обновите необходимые данные события.'
                    : 'Событие появится в вашем личном календаре.',
                style: AppTheme.secondaryBodyText,
              ),
              const SizedBox(height: 30),
              const _FieldTitle(title: 'Название'),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Например, подготовить презентацию',
                ),
              ),
              const SizedBox(height: 22),
              const _FieldTitle(title: 'Описание'),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 5,
                maxLines: 7,
                decoration: const InputDecoration(
                  hintText: 'Добавьте подробности события',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 22),
              const _FieldTitle(title: 'Дата и время'),
              const SizedBox(height: 8),
              _SelectionCard(
                icon: Icons.calendar_month_outlined,
                label: 'Дата',
                value: _formatDate(_selectedDate),
                onTap: _selectDate,
              ),
              const SizedBox(height: 10),
              _SelectionCard(
                icon: Icons.schedule_rounded,
                label: 'Время',
                value: _formatTime(_selectedDate),
                onTap: _selectTime,
              ),
              const SizedBox(height: 22),
              const _FieldTitle(title: 'Напоминание'),
              const SizedBox(height: 8),
              Material(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: PopupMenuButton<int?>(
                  initialValue: _reminderMinutesBefore,
                  onSelected: (value) {
                    setState(() {
                      _reminderMinutesBefore = value;
                    });
                  },
                  itemBuilder: (context) {
                    return _reminderOptions.map((option) {
                      return PopupMenuItem<int?>(
                        value: option.minutes,
                        child: Row(
                          children: [
                            if (_reminderMinutesBefore == option.minutes)
                              const Icon(
                                Icons.check_rounded,
                                color: AppTheme.primaryBlue,
                                size: 20,
                              )
                            else
                              const SizedBox(width: 20),
                            const SizedBox(width: 10),
                            Text(option.label),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.smallRadius,
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: AppTheme.primaryBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Уведомить',
                                style: AppTheme.labelText,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _reminderLabel(_reminderMinutesBefore),
                                style: AppTheme.cardTitle,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: AppTheme.secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveEvent,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'Сохранить изменения'
                              : 'Создать событие',
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

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.icon,
    required this.label,
    required this.value,
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
                child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTheme.labelText),
                    const SizedBox(height: 3),
                    Text(value, style: AppTheme.cardTitle),
                  ],
                ),
              ),
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

class _ReminderOption {
  final int? minutes;
  final String label;

  const _ReminderOption({required this.minutes, required this.label});
}

class _FieldTitle extends StatelessWidget {
  final String title;

  const _FieldTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTheme.cardTitle);
  }
}
