import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/teacher.dart';

class TeacherProfileScreen extends StatelessWidget {
  final Teacher teacher;

  const TeacherProfileScreen({
    super.key,
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Преподаватель',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            24,
            AppTheme.screenPadding,
            32,
          ),
          children: [
            _TeacherHeader(
              teacher: teacher,
            ),

            const SizedBox(height: 28),

            const Text(
              'Контактная информация',
              style: AppTheme.sectionTitle,
            ),

            const SizedBox(height: 14),

            if (teacher.email.trim().isNotEmpty)
              _InfoCard(
                icon: Icons.email_outlined,
                title: 'Email',
                value: teacher.email,
              ),

            if (teacher.email.trim().isNotEmpty)
              const SizedBox(height: 10),

            if (teacher.phone.trim().isNotEmpty)
              _InfoCard(
                icon: Icons.phone_outlined,
                title: 'Телефон',
                value: teacher.phone,
              ),

            if (teacher.phone.trim().isNotEmpty)
              const SizedBox(height: 10),

            if (teacher.telegram.trim().isNotEmpty)
              _InfoCard(
                icon: Icons.send_outlined,
                title: 'Telegram',
                value: teacher.telegram,
              ),

            if (!_hasContacts(teacher))
              const _EmptyContactsCard(),
          ],
        ),
      ),
    );
  }

  bool _hasContacts(Teacher teacher) {
    return teacher.email.trim().isNotEmpty ||
        teacher.phone.trim().isNotEmpty ||
        teacher.telegram.trim().isNotEmpty;
  }
}

class _TeacherHeader extends StatelessWidget {
  final Teacher teacher;

  const _TeacherHeader({
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TeacherAvatar(
          teacher: teacher,
        ),

        const SizedBox(height: 18),

        Text(
          teacher.name,
          textAlign: TextAlign.center,
          style: AppTheme.pageTitle,
        ),

        if (teacher.department.trim().isNotEmpty) ...[
          const SizedBox(height: 8),

          Text(
            teacher.department,
            textAlign: TextAlign.center,
            style: AppTheme.secondaryBodyText,
          ),
        ],
      ],
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  final Teacher teacher;

  const _TeacherAvatar({
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    final String? photoUrl =
        teacher.photoUrl;

    if (photoUrl != null &&
        photoUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(
          photoUrl,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return _buildPlaceholder();
          },
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.school_outlined,
        size: 44,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(
                AppTheme.smallRadius,
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color: AppTheme.primaryBlue,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.labelText,
                ),

                const SizedBox(height: 4),

                SelectableText(
                  value,
                  style: AppTheme.cardTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContactsCard extends StatelessWidget {
  const _EmptyContactsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.secondaryText,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'Контактная информация пока не указана',
              style: AppTheme.secondaryBodyText,
            ),
          ),
        ],
      ),
    );
  }
}