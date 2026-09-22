import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/admin_api_service.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  PlatformFile? selectedFile;

  ScheduleCheckResult? checkResult;
  SchedulePublishResult? publishResult;

  bool isChecking = false;
  bool isPublishing = false;

  bool get isBusy => isChecking || isPublishing;

  Future<void> _pickPdf() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file == null || !mounted) {
        return;
      }

      setState(() {
        selectedFile = file;
        checkResult = null;
        publishResult = null;
      });
    } catch (e) {
      debugPrint('Ошибка выбора PDF: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выбрать PDF-файл')),
      );
    }
  }

  void _removeSelectedFile() {
    if (isBusy) {
      return;
    }

    setState(() {
      selectedFile = null;
      checkResult = null;
      publishResult = null;
    });
  }

  Future<void> _checkSchedule() async {
    final PlatformFile? file = selectedFile;

    if (file == null || isBusy) {
      return;
    }

    setState(() {
      isChecking = true;
      checkResult = null;
      publishResult = null;
    });

    try {
      final ScheduleCheckResult result = await AdminApiService.checkSchedule(
        file,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        checkResult = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.auditPassed
                ? 'Расписание успешно проверено'
                : 'При проверке расписания '
                      'обнаружены проблемы',
          ),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('Ошибка проверки расписания: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось проверить '
            'расписание',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isChecking = false;
        });
      }
    }
  }

  Future<void> _requestPublish() async {
    final PlatformFile? file = selectedFile;

    final ScheduleCheckResult? result = checkResult;

    if (file == null || result == null || !result.auditPassed || isBusy) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Опубликовать расписание?'),
          content: Text(
            'Расписание на '
            '${_formatDate(result.date)} '
            'будет записано в Firestore.\n\n'
            'Занятий: '
            '${result.lessonCount}\n'
            'Групп: '
            '${result.groupCount}\n\n'
            'Если расписание на эту дату '
            'уже существует, оно будет '
            'обновлено.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Опубликовать'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _publishSchedule(file);
  }

  Future<void> _publishSchedule(PlatformFile file) async {
    setState(() {
      isPublishing = true;
      publishResult = null;
    });

    try {
      final SchedulePublishResult result =
          await AdminApiService.publishSchedule(file);

      if (!mounted) {
        return;
      }

      setState(() {
        publishResult = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty ? 'Расписание опубликовано' : result.message,
          ),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint(
        'Ошибка публикации '
        'расписания: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось опубликовать '
            'расписание',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isPublishing = false;
        });
      }
    }
  }

  String _formatDate(String value) {
    final DateTime? date = DateTime.tryParse(value);

    if (date == null) {
      return value.isEmpty ? 'неизвестную дату' : value;
    }

    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Управление расписанием')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Расписание', style: AppTheme.pageTitle),

              const SizedBox(height: 8),

              const Text(
                'Загрузите PDF-файл '
                'с расписанием колледжа. '
                'Перед публикацией данные '
                'будут проверены.',
                style: AppTheme.secondaryBodyText,
              ),

              const SizedBox(height: 28),

              _UploadCard(onTap: isBusy ? null : _pickPdf),

              if (selectedFile != null) ...[
                const SizedBox(height: 20),

                const Text('Выбранный файл', style: AppTheme.sectionTitle),

                const SizedBox(height: 12),

                _SelectedFileCard(
                  fileName: selectedFile!.name,
                  onRemove: isBusy ? null : _removeSelectedFile,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : _checkSchedule,
                    icon: isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fact_check_rounded),
                    label: Text(
                      isChecking ? 'Проверяем...' : 'Проверить расписание',
                    ),
                  ),
                ),
              ],

              if (checkResult != null) ...[
                const SizedBox(height: 28),

                _CheckResultCard(result: checkResult!),

                if (checkResult!.auditPassed) ...[
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : _requestPublish,
                      icon: isPublishing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                        isPublishing
                            ? 'Публикуем...'
                            : 'Опубликовать расписание',
                      ),
                    ),
                  ),
                ],
              ],

              if (publishResult != null) ...[
                const SizedBox(height: 28),

                _PublishResultCard(result: publishResult!),
              ],

              const SizedBox(height: 32),

              const Text(
                'Как это будет работать',
                style: AppTheme.sectionTitle,
              ),

              const SizedBox(height: 14),

              const _ProcessStep(
                number: '1',
                title: 'Выбор PDF',
                description:
                    'Администратор выбирает '
                    'файл с расписанием.',
              ),

              const SizedBox(height: 12),

              const _ProcessStep(
                number: '2',
                title: 'Проверка',
                description:
                    'Сервер распознаёт '
                    'расписание и проверяет '
                    'полученные данные.',
              ),

              const SizedBox(height: 12),

              const _ProcessStep(
                number: '3',
                title: 'Предпросмотр',
                description:
                    'Перед публикацией '
                    'администратор увидит '
                    'результаты обработки.',
              ),

              const SizedBox(height: 12),

              const _ProcessStep(
                number: '4',
                title: 'Публикация',
                description:
                    'После подтверждения '
                    'расписание будет записано '
                    'в Firestore.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 32,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Выбрать PDF-файл',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryText,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Нажмите, чтобы выбрать '
                'расписание на устройстве',
                textAlign: TextAlign.center,
                style: AppTheme.secondaryBodyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedFileCard extends StatelessWidget {
  const _SelectedFileCard({required this.fileName, required this.onRemove});

  final String fileName;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppTheme.primaryBlue,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.cardTitle,
                ),
                const SizedBox(height: 4),
                const Text('PDF-документ', style: AppTheme.labelText),
              ],
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            onPressed: onRemove,
            tooltip: 'Удалить',
            icon: const Icon(
              Icons.close_rounded,
              color: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckResultCard extends StatelessWidget {
  const _CheckResultCard({required this.result});

  final ScheduleCheckResult result;

  @override
  Widget build(BuildContext context) {
    final bool passed = result.auditPassed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: passed
              ? AppTheme.success.withValues(alpha: 0.55)
              : AppTheme.danger.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.check_circle_rounded : Icons.error_rounded,
                color: passed ? AppTheme.success : AppTheme.danger,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  passed ? 'Проверка пройдена' : 'Обнаружены проблемы',
                  style: AppTheme.sectionTitle,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _ResultRow(
            title: 'Дата',
            value: result.date.isEmpty ? 'Не определена' : result.date,
          ),

          const SizedBox(height: 10),

          _ResultRow(title: 'Занятий', value: '${result.lessonCount}'),

          const SizedBox(height: 10),

          _ResultRow(title: 'Групп', value: '${result.groupCount}'),

          const SizedBox(height: 10),

          _ResultRow(title: 'Предметов', value: '${result.subjectCount}'),

          const SizedBox(height: 10),

          _ResultRow(title: 'Преподавателей', value: '${result.teacherCount}'),

          const SizedBox(height: 10),

          _ResultRow(
            title: 'Без преподавателя',
            value: '${result.withoutTeacher}',
          ),

          const SizedBox(height: 10),

          _ResultRow(title: 'Без аудитории', value: '${result.withoutRoom}'),

          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            const Text('Найденные проблемы', style: AppTheme.cardTitle),

            const SizedBox(height: 10),

            ...result.issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppTheme.danger,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(issue, style: AppTheme.secondaryBodyText),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublishResultCard extends StatelessWidget {
  const _PublishResultCard({required this.result});

  final SchedulePublishResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: AppTheme.success),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Расписание опубликовано',
                  style: AppTheme.sectionTitle,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _ResultRow(title: 'Дата', value: result.date),

          const SizedBox(height: 10),

          _ResultRow(
            title: 'Опубликовано занятий',
            value: '${result.lessonCount}',
          ),

          const SizedBox(height: 10),

          _ResultRow(
            title: 'Занятий было до публикации',
            value: '${result.previousLessonCount}',
          ),

          const SizedBox(height: 10),

          _ResultRow(
            title: 'Удалено устаревших',
            value: '${result.deletedLessonCount}',
          ),

          const SizedBox(height: 10),

          _ResultRow(
            title: 'Добавлено преподавателей',
            value: '${result.teachersCreated}',
          ),

          const SizedBox(height: 10),

          _ResultRow(
            title: 'Обновлено преподавателей',
            value: '${result.teachersUpdated}',
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTheme.secondaryBodyText)),

        const SizedBox(width: 12),

        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryText,
          ),
        ),
      ],
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSecondary,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.cardTitle),

                const SizedBox(height: 4),

                Text(description, style: AppTheme.secondaryBodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
