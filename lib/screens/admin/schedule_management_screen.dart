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
  bool isChecking = false;

  Future<void> _pickPdf() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        selectedFile = file;
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
    setState(() {
      selectedFile = null;
    });
  }

  Future<void> _checkAdminAccess() async {
    if (selectedFile == null || isChecking) {
      return;
    }

    setState(() {
      isChecking = true;
    });

    try {
      final Map<String, dynamic> result =
          await AdminApiService.checkAdminAccess();

      debugPrint('Ответ Admin API: $result');

      if (!mounted) {
        return;
      }

      final String message =
          result['message']?.toString() ?? 'Администратор авторизован';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('Ошибка Admin API: $e');

      if (!mounted) {
        return;
      }

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isChecking = false;
        });
      }
    }
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

              _UploadCard(onTap: isChecking ? null : _pickPdf),

              if (selectedFile != null) ...[
                const SizedBox(height: 20),

                const Text('Выбранный файл', style: AppTheme.sectionTitle),

                const SizedBox(height: 12),

                _SelectedFileCard(
                  fileName: selectedFile!.name,
                  onRemove: isChecking ? null : _removeSelectedFile,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isChecking ? null : _checkAdminAccess,
                    icon: isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_user_rounded),
                    label: Text(
                      isChecking
                          ? 'Проверяем доступ...'
                          : 'Проверить расписание',
                    ),
                  ),
                ),
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
