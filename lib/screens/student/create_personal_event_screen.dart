import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/personal_event.dart';
import '../../services/personal_event_service.dart';

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

class _CreatePersonalEventScreenState
    extends State<CreatePersonalEventScreen> {
  final PersonalEventService _personalEventService =
      PersonalEventService();

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  late DateTime _selectedDate;

  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();

    final PersonalEvent? event = widget.event;

    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _selectedDate = event.date;
    } else {
      _selectedDate = widget.initialDate;
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
      _selectedDate = result;
    });
  }

  Future<void> _saveEvent() async {
    final String title =
        _titleController.text.trim();

    final String description =
        _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Введите название события',
          ),
        ),
      );
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось определить пользователя',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        final String? eventId =
            widget.event?.id;

        if (eventId == null) {
          throw Exception(
            'Не удалось определить событие',
          );
        }

        await _personalEventService.updateEvent(
          eventId: eventId,
          title: title,
          description: description,
          date: _selectedDate,
        );
      } else {
        final PersonalEvent event =
            PersonalEvent(
          userId: user.uid,
          title: title,
          description: description,
          date: _selectedDate,
        );

        await _personalEventService.createEvent(
          event: event,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint(
        'Ошибка сохранения личного события: $error',
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Редактирование события'
              : 'Новое событие',
        ),
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? 'Измените информацию'
                    : 'Добавьте событие',
                style: AppTheme.pageTitle,
              ),

              const SizedBox(height: 8),

              Text(
                _isEditing
                    ? 'Обновите необходимые данные события.'
                    : 'Событие появится в вашем личном календаре.',
                style:
                    AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 30),

              const _FieldTitle(
                title: 'Название',
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _titleController,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Например, подготовить презентацию',
                ),
              ),

              const SizedBox(height: 22),

              const _FieldTitle(
                title: 'Описание',
              ),

              const SizedBox(height: 8),

              TextField(
                controller:
                    _descriptionController,
                textCapitalization:
                    TextCapitalization.sentences,
                minLines: 5,
                maxLines: 7,
                decoration: const InputDecoration(
                  hintText:
                      'Добавьте подробности события',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 22),

              const _FieldTitle(
                title: 'Дата',
              ),

              const SizedBox(height: 8),

              Material(
                color: AppTheme.card,
                borderRadius:
                    BorderRadius.circular(
                  AppTheme.cardRadius,
                ),
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius:
                      BorderRadius.circular(
                    AppTheme.cardRadius,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              BoxDecoration(
                            color: AppTheme
                                .primaryBlue
                                .withValues(
                              alpha: 0.15,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              AppTheme
                                  .smallRadius,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .calendar_month_outlined,
                            color: AppTheme
                                .primaryBlue,
                            size: 22,
                          ),
                        ),

                        const SizedBox(
                          width: 14,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                'Выбранная дата',
                                style: AppTheme
                                    .labelText,
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                _formatDate(
                                  _selectedDate,
                                ),
                                style: AppTheme
                                    .cardTitle,
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          Icons
                              .chevron_right_rounded,
                          color: AppTheme
                              .secondaryText,
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
                  onPressed: _isSaving
                      ? null
                      : _saveEvent,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
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

class _FieldTitle extends StatelessWidget {
  final String title;

  const _FieldTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTheme.cardTitle,
    );
  }
}