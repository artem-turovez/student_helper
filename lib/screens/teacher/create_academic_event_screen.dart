import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/academic_event.dart';
import '../../models/lesson.dart';
import '../../services/academic_event_service.dart';
import '../../services/notification_service.dart';
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
  String? _selectedGroupId;

  late DateTime _selectedDate;
  late String _selectedType;

  bool _isLoadingLessons = true;
  bool _isSaving = false;
  bool _hasLessonsError = false;

  bool get _isEditing => widget.event != null;

  List<Lesson> get _lessonsForSelectedDate {
    return _lessons.where((lesson) {
      final DateTime? date = lesson.date;

      return date != null && _isSameDay(date, _selectedDate);
    }).toList();
  }

  List<String> get _groupsForSelectedDate {
    final Set<String> groups = {};

    for (final Lesson lesson in _lessonsForSelectedDate) {
      final String groupId = lesson.groupId?.trim() ?? '';

      if (groupId.isNotEmpty) {
        groups.add(groupId);
      }
    }

    final List<String> result = groups.toList()..sort();

    return result;
  }

  List<Lesson> get _lessonsForSelectedGroup {
    final String? groupId = _selectedGroupId;

    if (groupId == null) {
      return [];
    }

    final List<Lesson> result = _lessonsForSelectedDate.where((lesson) {
      return lesson.groupId?.trim() == groupId;
    }).toList();

    result.sort((first, second) {
      final int numberComparison = first.number.compareTo(second.number);

      if (numberComparison != 0) {
        return numberComparison;
      }

      return first.time.compareTo(second.time);
    });

    return result;
  }

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

      final Lesson? initialLesson = _findInitialLesson(validLessons);

      if (!mounted) {
        return;
      }

      setState(() {
        _lessons = validLessons;
        _selectedLesson = initialLesson;

        if (initialLesson != null) {
          final DateTime? lessonDate = initialLesson.date;

          if (lessonDate != null) {
            _selectedDate = DateTime(
              lessonDate.year,
              lessonDate.month,
              lessonDate.day,
            );
          }

          _selectedGroupId = initialLesson.groupId?.trim();
        }

        _isLoadingLessons = false;
        _hasLessonsError = false;
      });

      _autoSelectIfPossible();
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
        _selectedGroupId = null;
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
        _selectedGroupId = null;
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

      final DateTime lessonDay = DateTime(
        date.year,
        date.month,
        date.day,
      );

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

  void _autoSelectIfPossible() {
    if (!mounted) {
      return;
    }

    final List<String> groups = _groupsForSelectedDate;

    if (_selectedGroupId == null && groups.length == 1) {
      setState(() {
        _selectedGroupId = groups.first;
      });
    }

    final List<Lesson> lessons = _lessonsForSelectedGroup;

    if (_selectedLesson == null && lessons.length == 1) {
      setState(() {
        _selectedLesson = lessons.first;
      });
    }
  }

  Future<void> _selectDate() async {
    if (_isSaving || _isLoadingLessons) {
      return;
    }

    DateTime firstDate = _selectedDate;

    if (_lessons.isNotEmpty) {
      final Iterable<DateTime> dates = _lessons
          .map((lesson) => lesson.date)
          .whereType<DateTime>();

      if (dates.isNotEmpty) {
        firstDate = dates.reduce(
          (first, second) => first.isBefore(second) ? first : second,
        );
      }
    }

    DateTime lastDate = _selectedDate;

    if (_lessons.isNotEmpty) {
      final Iterable<DateTime> dates = _lessons
          .map((lesson) => lesson.date)
          .whereType<DateTime>();

      if (dates.isNotEmpty) {
        lastDate = dates.reduce(
          (first, second) => first.isAfter(second) ? first : second,
        );
      }
    }

    final DateTime? result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(
        firstDate.year,
        firstDate.month,
        firstDate.day,
      ),
      lastDate: DateTime(
        lastDate.year,
        lastDate.month,
        lastDate.day,
      ),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        result.year,
        result.month,
        result.day,
      );

      _selectedGroupId = null;
      _selectedLesson = null;
    });

    _autoSelectIfPossible();
  }

  Future<void> _showGroupPicker() async {
    if (_isSaving) {
      return;
    }

    final List<String> groups = _groupsForSelectedDate;

    if (groups.isEmpty) {
      _showMessage('На выбранную дату занятий нет');
      return;
    }

    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),

                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryText.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Выберите группу',
                        style: AppTheme.sectionTitle,
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final String group = groups[index];
                      final bool selected = group == _selectedGroupId;

                      return Material(
                        color: selected
                            ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppTheme.smallRadius,
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.smallRadius,
                            ),
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: selected ? 0.18 : 0.10,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.smallRadius,
                              ),
                            ),
                            child: const Icon(
                              Icons.groups_outlined,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          title: Text(
                            group,
                            style: AppTheme.cardTitle,
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.primaryBlue,
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.secondaryText,
                                ),
                          onTap: () {
                            Navigator.of(context).pop(group);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _selectedGroupId = result;
      _selectedLesson = null;
    });

    _autoSelectIfPossible();
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
      _showMessage('Выберите пару');
      return;
    }

    final String lessonId = lesson.id?.trim() ?? '';
    final String groupId = lesson.groupId?.trim() ?? '';
    final String subject = lesson.subject.trim();
    final String lessonTime = lesson.time.trim();

    if (lessonId.isEmpty ||
        groupId.isEmpty ||
        subject.isEmpty ||
        lessonTime.isEmpty) {
      _showMessage('У выбранного занятия отсутствуют необходимые данные');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      late final String eventId;

      if (_isEditing) {
        eventId = widget.event?.id?.trim() ?? '';

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
        eventId = await _academicEventService.createAcademicEvent(
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

      try {
        await NotificationService.instance.scheduleAcademicEventReminder(
          eventId: eventId,
          subject: subject,
          type: _selectedType,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          eventDate: _selectedDate,
          lessonTime: lessonTime,
        );
      } catch (notificationError) {
        debugPrint(
          'Ошибка планирования напоминания учебного события: '
          '$notificationError',
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Widget _buildLessonSelection() {
    if (_isLoadingLessons) {
      return const _StateCard(
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
              ),
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
            Icon(
              Icons.info_outline,
              color: AppTheme.secondaryText,
            ),
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

    final List<String> groups = _groupsForSelectedDate;
    final List<Lesson> groupLessons = _lessonsForSelectedGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SelectionTile(
          icon: Icons.calendar_month_outlined,
          title: 'Дата',
          value: _formatDate(_selectedDate),
          onTap: _selectDate,
        ),

        const SizedBox(height: 12),

        _SelectionTile(
          icon: Icons.groups_outlined,
          title: 'Группа',
          value: _selectedGroupId ?? 'Выберите группу',
          enabled: groups.isNotEmpty,
          onTap: _showGroupPicker,
        ),

        if (groups.isEmpty) ...[
          const SizedBox(height: 10),
          const _HintCard(
            icon: Icons.event_busy_outlined,
            text: 'На эту дату у преподавателя нет занятий.',
          ),
        ],

        if (_selectedGroupId != null && groupLessons.isNotEmpty) ...[
          const SizedBox(height: 22),

          const Text(
            'Выберите пару',
            style: AppTheme.labelText,
          ),

          const SizedBox(height: 10),

          ...groupLessons.map((lesson) {
            final bool selected =
                (lesson.id?.trim() ?? '') ==
                (_selectedLesson?.id?.trim() ?? '');

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LessonChoiceCard(
                lesson: lesson,
                selected: selected,
                onTap: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _selectedLesson = lesson;
                        });
                      },
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Lesson? selectedLesson = _selectedLesson;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Редактирование события'
              : 'Учебное событие',
        ),
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
                'Выберите дату, группу и пару. '
                'Событие будет доступно учащимся выбранной группы.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 28),

              const Text(
                'Занятие',
                style: AppTheme.sectionTitle,
              ),

              const SizedBox(height: 12),

              _buildLessonSelection(),

              if (selectedLesson != null) ...[
                const SizedBox(height: 12),
                _LessonInfoCard(
                  lesson: selectedLesson,
                ),
              ],

              const SizedBox(height: 26),

              const Text(
                'Событие',
                style: AppTheme.sectionTitle,
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Тип события',
                  prefixIcon: Icon(
                    Icons.category_outlined,
                  ),
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
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              FilledButton.icon(
                onPressed:
                    _isSaving ||
                        _isLoadingLessons ||
                        _lessons.isEmpty ||
                        _selectedLesson == null
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
                    : const Icon(
                        Icons.check_rounded,
                      ),
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

class _SelectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(
        AppTheme.cardRadius,
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(
                    alpha: enabled ? 0.14 : 0.06,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.smallRadius,
                  ),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? AppTheme.primaryBlue
                      : AppTheme.secondaryText,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.secondaryBodyText,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: AppTheme.cardTitle,
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: enabled
                    ? AppTheme.secondaryText
                    : AppTheme.secondaryText.withValues(
                        alpha: 0.4,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonChoiceCard extends StatelessWidget {
  final Lesson lesson;
  final bool selected;
  final VoidCallback? onTap;

  const _LessonChoiceCard({
    required this.lesson,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String subject = lesson.subject.trim().isEmpty
        ? 'Предмет не указан'
        : lesson.subject.trim();

    final String room = lesson.room.trim();

    return Material(
      color: selected
          ? AppTheme.primaryBlue.withValues(alpha: 0.12)
          : AppTheme.card,
      borderRadius: BorderRadius.circular(
        AppTheme.cardRadius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppTheme.cardRadius,
            ),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.65)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(
                    alpha: selected ? 0.18 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.smallRadius,
                  ),
                ),
                child: Text(
                  '${lesson.number}',
                  style: AppTheme.cardTitle,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${lesson.number} пара',
                            style: AppTheme.cardTitle,
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.primaryBlue,
                            size: 22,
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      lesson.time,
                      style: AppTheme.secondaryBodyText,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      subject,
                      style: AppTheme.labelText,
                    ),

                    if (room.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            size: 16,
                            color: AppTheme.secondaryText,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              room,
                              style: AppTheme.secondaryBodyText,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (lesson.subgroup?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Подгруппа: ${lesson.subgroup}',
                        style: AppTheme.secondaryBodyText,
                      ),
                    ],
                  ],
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

  const _LessonInfoCard({
    required this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    final String groupId = lesson.groupId?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.subject,
            style: AppTheme.cardTitle,
          ),

          const SizedBox(height: 10),

          _InfoRow(
            icon: Icons.groups_outlined,
            text: groupId.isEmpty
                ? 'Группа не указана'
                : 'Группа $groupId',
          ),

          const SizedBox(height: 7),

          _InfoRow(
            icon: Icons.access_time_outlined,
            text: '${lesson.number} пара • ${lesson.time}',
          ),

          if (lesson.room.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.meeting_room_outlined,
              text: lesson.room,
            ),
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

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(
          AppTheme.smallRadius,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: AppTheme.secondaryText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.secondaryBodyText,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.secondaryText,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: AppTheme.secondaryBodyText,
          ),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  final Widget child;

  const _StateCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: child,
    );
  }
}