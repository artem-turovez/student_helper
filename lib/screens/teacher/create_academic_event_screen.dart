import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/academic_event.dart';
import '../../models/lesson.dart';
import '../../services/academic_event_service.dart';
import '../../services/schedule_service.dart';

class CreateAcademicEventScreen extends StatefulWidget {
  final String teacherId;
  final DateTime initialDate;
  final AcademicEvent? event;

  const CreateAcademicEventScreen({
    super.key,
    required this.teacherId,
    required this.initialDate,
    this.event,
  });

  @override
  State<CreateAcademicEventScreen> createState() =>
      _CreateAcademicEventScreenState();
}

class _CreateAcademicEventScreenState extends State<CreateAcademicEventScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ScheduleService _scheduleService = ScheduleService();
  final AcademicEventService _academicEventService = AcademicEventService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  static const List<String> _eventTypes = [
    'Лабораторная работа',
    'Контрольная работа',
    'Тест',
    'Экзамен',
    'ОКР',
    'Другое',
  ];

  List<Lesson> _lessons = [];

  Lesson? _selectedLesson;

  late DateTime _selectedDate;
  late String _selectedType;

  bool _isLoadingLessons = true;
  bool _isSaving = false;
  bool _hasLessonsError = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();

    final AcademicEvent? event = widget.event;

    if (event != null) {
      _selectedDate = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );

      _selectedType = _eventTypes.contains(event.type)
          ? event.type
          : _eventTypes.last;

      _titleController.text = event.title;
      _descriptionController.text = event.description;
    } else {
      _selectedDate = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
      );

      _selectedType = _eventTypes.first;
    }

    _loadLessons();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoadingLessons = true;
      _hasLessonsError = false;
    });

    try {
      final List<Lesson> lessons = await _scheduleService.getLessonsForTeacher(
        teacherId: widget.teacherId,
      );

      final List<Lesson> validLessons = lessons.where((lesson) {
        final String lessonId = lesson.id?.trim() ?? '';
        final String groupId = lesson.groupId?.trim() ?? '';

        return lessonId.isNotEmpty &&
            groupId.isNotEmpty &&
            lesson.teacherIds.contains(widget.teacherId);
      }).toList();

      validLessons.sort(_compareLessons);

      final Lesson? selectedLesson = _findInitialLesson(validLessons);

      if (!mounted) {
        return;
      }

      setState(() {
        _lessons = validLessons;
        _selectedLesson = selectedLesson;
        _isLoadingLessons = false;
        _hasLessonsError = false;
      });
    } on FirebaseException catch (error) {
      debugPrint(
        'Ошибка Firebase при загрузке занятий для учебного события: '
        '${error.code} | ${error.message}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lessons = [];
        _selectedLesson = null;
        _isLoadingLessons = false;
        _hasLessonsError = true;
      });
    } catch (error) {
      debugPrint('Ошибка загрузки занятий для учебного события: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _lessons = [];
        _selectedLesson = null;
        _isLoadingLessons = false;
        _hasLessonsError = true;
      });
    }
  }

  Lesson? _findInitialLesson(List<Lesson> lessons) {
    if (lessons.isEmpty) {
      return null;
    }

    final String existingLessonId = widget.event?.lessonId?.trim() ?? '';

    if (existingLessonId.isNotEmpty) {
      for (final Lesson lesson in lessons) {
        if ((lesson.id?.trim() ?? '') == existingLessonId) {
          return lesson;
        }
      }
    }

    return _findBestInitialLesson(lessons);
  }

  Lesson? _findBestInitialLesson(List<Lesson> lessons) {
    if (lessons.isEmpty) {
      return null;
    }

    for (final Lesson lesson in lessons) {
      final DateTime? date = lesson.date;

      if (date != null && _isSameDay(date, _selectedDate)) {
        return lesson;
      }
    }

    final DateTime selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    for (final Lesson lesson in lessons) {
      final DateTime? date = lesson.date;

      if (date == null) {
        continue;
      }

      final DateTime lessonDay = DateTime(date.year, date.month, date.day);

      if (!lessonDay.isBefore(selectedDay)) {
        return lesson;
      }
    }

    return lessons.first;
  }

  int _compareLessons(Lesson first, Lesson second) {
    final DateTime? firstDate = first.date;
    final DateTime? secondDate = second.date;

    if (firstDate == null && secondDate == null) {
      return first.number.compareTo(second.number);
    }

    if (firstDate == null) {
      return 1;
    }

    if (secondDate == null) {
      return -1;
    }

    final int dateComparison = firstDate.compareTo(secondDate);

    if (dateComparison != 0) {
      return dateComparison;
    }

    return first.number.compareTo(second.number);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Дата учебного события',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (date == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final Lesson? lesson = _selectedLesson;

    if (lesson == null) {
      _showMessage('Выберите занятие');
      return;
    }

    final String lessonId = lesson.id?.trim() ?? '';
    final String groupId = lesson.groupId?.trim() ?? '';
    final String subject = lesson.subject.trim();

    if (lessonId.isEmpty || groupId.isEmpty || subject.isEmpty) {
      _showMessage('У выбранного занятия отсутствуют необходимые данные');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        final String eventId = widget.event?.id?.trim() ?? '';

        if (eventId.isEmpty) {
          throw Exception('У учебного события отсутствует ID');
        }

        await _academicEventService.updateAcademicEvent(
          eventId: eventId,
          groupId: groupId,
          lessonId: lessonId,
          teacherId: widget.teacherId,
          subject: subject,
          type: _selectedType,
          title: _titleController.text,
          description: _descriptionController.text,
          date: _selectedDate,
        );
      } else {
        await _academicEventService.createAcademicEvent(
          groupId: groupId,
          lessonId: lessonId,
          teacherId: widget.teacherId,
          subject: subject,
          type: _selectedType,
          title: _titleController.text,
          description: _descriptionController.text,
          date: _selectedDate,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      debugPrint(
        'Ошибка Firebase при сохранении учебного события: '
        '${error.code} | ${error.message}',
      );

      if (!mounted) {
        return;
      }

      if (error.code == 'permission-denied') {
        _showMessage(
          _isEditing
              ? 'Нет разрешения на редактирование учебного события'
              : 'Нет разрешения на создание учебного события',
        );
      } else if (error.code == 'unavailable') {
        _showMessage('Нет подключения к серверу. Попробуйте позже');
      } else {
        _showMessage('Не удалось сохранить учебное событие');
      }
    } catch (error) {
      debugPrint('Ошибка сохранения учебного события: $error');

      if (!mounted) {
        return;
      }

      _showMessage('Не удалось сохранить учебное событие');
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
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String _lessonLabel(Lesson lesson) {
    final DateTime? date = lesson.date;

    final String dateText = date == null ? 'Без даты' : _formatDate(date);

    final String groupId = lesson.groupId?.trim().isNotEmpty == true
        ? lesson.groupId!.trim()
        : 'Без группы';

    final String subject = lesson.subject.trim().isEmpty
        ? 'Предмет не указан'
        : lesson.subject.trim();

    return '$subject • $groupId • $dateText';
  }

  Widget _buildLessonsField() {
    if (_isLoadingLessons) {
      return const _StateCard(
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Загружаем занятия преподавателя...',
                style: AppTheme.secondaryBodyText,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasLessonsError) {
      return _StateCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Не удалось загрузить занятия',
              style: AppTheme.cardTitle,
            ),
            const SizedBox(height: 6),
            const Text(
              'Проверьте подключение и повторите попытку.',
              style: AppTheme.secondaryBodyText,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadLessons,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_lessons.isEmpty) {
      return const _StateCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppTheme.secondaryText),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Для этого преподавателя не найдено занятий, '
                'к которым можно привязать учебное событие.',
                style: AppTheme.secondaryBodyText,
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<Lesson>(
      initialValue: _selectedLesson,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Предмет и группа',
        prefixIcon: Icon(Icons.school_outlined),
      ),
      items: _lessons.map((lesson) {
        return DropdownMenuItem<Lesson>(
          value: lesson,
          child: Text(
            _lessonLabel(lesson),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _isSaving
          ? null
          : (lesson) {
              setState(() {
                _selectedLesson = lesson;
              });
            },
      validator: (lesson) {
        if (lesson == null) {
          return 'Выберите занятие';
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Lesson? selectedLesson = _selectedLesson;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактирование события' : 'Учебное событие'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              24,
              AppTheme.screenPadding,
              32,
            ),
            children: [
              Text(
                _isEditing
                    ? 'Редактирование учебного события'
                    : 'Новое учебное событие',
                style: AppTheme.pageTitle,
              ),

              const SizedBox(height: 8),

              const Text(
                'Событие будет доступно учащимся выбранной группы.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 28),

              const Text('Предмет и группа', style: AppTheme.sectionTitle),

              const SizedBox(height: 12),

              _buildLessonsField(),

              if (selectedLesson != null) ...[
                const SizedBox(height: 12),
                _LessonInfoCard(lesson: selectedLesson),
              ],

              const SizedBox(height: 26),

              const Text('Событие', style: AppTheme.sectionTitle),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Тип события',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _eventTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _selectedType = value;
                        });
                      },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например, Контрольная по теме 3',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  final String title = value?.trim() ?? '';

                  if (title.isEmpty) {
                    return 'Введите название';
                  }

                  if (title.length < 2) {
                    return 'Название слишком короткое';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 6),

              TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  hintText: 'Дополнительная информация',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),

              const SizedBox(height: 8),

              Material(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: InkWell(
                  onTap: _isSaving ? null : _selectDate,
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.smallRadius,
                            ),
                          ),
                          child: const Icon(
                            Icons.calendar_month_outlined,
                            color: AppTheme.primaryBlue,
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Дата события',
                                style: AppTheme.labelText,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(_selectedDate),
                                style: AppTheme.cardTitle,
                              ),
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
              ),

              const SizedBox(height: 30),

              FilledButton.icon(
                onPressed: _isSaving || _isLoadingLessons || _lessons.isEmpty
                    ? null
                    : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isSaving
                      ? 'Сохранение...'
                      : _isEditing
                      ? 'Сохранить изменения'
                      : 'Создать событие',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonInfoCard extends StatelessWidget {
  final Lesson lesson;

  const _LessonInfoCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final String groupId = lesson.groupId?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lesson.subject, style: AppTheme.cardTitle),

          const SizedBox(height: 10),

          _InfoRow(
            icon: Icons.groups_outlined,
            text: groupId.isEmpty ? 'Группа не указана' : 'Группа $groupId',
          ),

          const SizedBox(height: 7),

          _InfoRow(
            icon: Icons.access_time_outlined,
            text: '${lesson.number} пара • ${lesson.time}',
          ),

          if (lesson.room.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _InfoRow(icon: Icons.meeting_room_outlined, text: lesson.room),
          ],

          if (lesson.subgroup?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.group_work_outlined,
              text: 'Подгруппа: ${lesson.subgroup}',
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryText),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: AppTheme.secondaryBodyText)),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  final Widget child;

  const _StateCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: child,
    );
  }
}
