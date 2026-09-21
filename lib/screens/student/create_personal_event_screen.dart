import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            32,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Название',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _titleController,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:
                      'Например, подготовить презентацию',
                  filled: true,
                  fillColor:
                      const Color(0xFF10213D),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Описание',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller:
                    _descriptionController,
                textCapitalization:
                    TextCapitalization.sentences,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Добавьте подробности события',
                  filled: true,
                  fillColor:
                      const Color(0xFF10213D),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Дата',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              InkWell(
                onTap: _selectDate,
                borderRadius:
                    BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF10213D),
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color:
                            Color(0xFF2B7FFF),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          _formatDate(
                            _selectedDate,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),

                      const Icon(
                        Icons.chevron_right,
                        color:
                            Color(0xFFB6C5E0),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving
                      ? null
                      : _saveEvent,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF2B7FFF),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
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
                          style:
                              const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w600,
                          ),
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