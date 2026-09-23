import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/public_profile.dart';

class ContactProfileScreen extends StatelessWidget {
  final PublicProfile profile;

  const ContactProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final bool hasEmail =
        profile.showEmail &&
        profile.email != null &&
        profile.email!.trim().isNotEmpty;

    final bool hasPhone =
        profile.showPhone &&
        profile.phone != null &&
        profile.phone!.trim().isNotEmpty;

    final bool hasTelegram =
        profile.showTelegram &&
        profile.telegram != null &&
        profile.telegram!.trim().isNotEmpty;

    final bool hasContacts = hasEmail || hasPhone || hasTelegram;

    return Scaffold(
      appBar: AppBar(title: const Text('Контакт')),
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
              Center(
                child: Column(
                  children: [
                    _ProfileAvatar(profile: profile),
                    const SizedBox(height: 18),
                    Text(
                      profile.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    if (profile.groupId != null &&
                        profile.groupId!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Группа ${profile.groupId}',
                        style: AppTheme.secondaryBodyText,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 34),
              const Text('Контактная информация', style: AppTheme.sectionTitle),
              const SizedBox(height: 12),
              if (!hasContacts)
                const _EmptyContactsCard()
              else ...[
                if (hasTelegram)
                  _ContactInfoCard(
                    icon: Icons.send_outlined,
                    title: 'Telegram',
                    value: profile.telegram!,
                  ),
                if (hasTelegram && hasPhone) const SizedBox(height: 10),
                if (hasPhone)
                  _ContactInfoCard(
                    icon: Icons.phone_outlined,
                    title: 'Телефон',
                    value: profile.phone!,
                  ),
                if ((hasTelegram || hasPhone) && hasEmail)
                  const SizedBox(height: 10),
                if (hasEmail)
                  _ContactInfoCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: profile.email!,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final PublicProfile profile;

  const _ProfileAvatar({required this.profile});

  String _getInitials() {
    final List<String> parts = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'У';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = profile.photoUrl;

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 46,
        backgroundColor: AppTheme.card,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return Container(
      width: 92,
      height: 92,
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(),
        style: const TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ContactInfoCard({
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
            child: const Icon(
              Icons.person_outline,
              size: 22,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelText),
                const SizedBox(height: 3),
                Text(value, style: AppTheme.cardTitle),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: const Icon(
              Icons.visibility_off_outlined,
              size: 25,
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Контактные данные скрыты',
            textAlign: TextAlign.center,
            style: AppTheme.cardTitle,
          ),
          const SizedBox(height: 6),
          const Text(
            'Пользователь не разрешил показывать контактную информацию.',
            textAlign: TextAlign.center,
            style: AppTheme.secondaryBodyText,
          ),
        ],
      ),
    );
  }
}
