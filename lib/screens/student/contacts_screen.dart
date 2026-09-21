import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/public_profile.dart';
import '../../services/public_profile_service.dart';
import 'contact_profile_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() =>
      _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final PublicProfileService _publicProfileService =
      PublicProfileService();

  List<PublicProfile> _classmates = [];

  bool _isLoading = true;
  bool _hasError = false;

  int _selectedList = 0;

  @override
  void initState() {
    super.initState();
    _loadClassmates();
  }

  Future<void> _loadClassmates() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Пользователь не авторизован',
        );
      }

      final DocumentSnapshot<Map<String, dynamic>>
          userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? userData =
          userDocument.data();

      final String? groupId =
          userData?['groupId']?.toString();

      if (groupId == null ||
          groupId.trim().isEmpty) {
        throw Exception(
          'Учебная группа не назначена',
        );
      }

      final List<PublicProfile> classmates =
          await _publicProfileService.getClassmates(
        groupId: groupId,
        currentUserId: user.uid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _classmates = classmates;
        _isLoading = false;
        _hasError = false;
      });
    } catch (error) {
      debugPrint(
        'Ошибка загрузки контактов: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _classmates = [];
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _openProfile(
    PublicProfile profile,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ContactProfileScreen(
          profile: profile,
        ),
      ),
    );
  }

  void _selectList(int index) {
    setState(() {
      _selectedList = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadClassmates,
        color: AppTheme.primaryBlue,
        backgroundColor: AppTheme.card,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            24,
            AppTheme.screenPadding,
            32,
          ),
          children: [
            const Text(
              'Контакты',
              style: AppTheme.pageTitle,
            ),

            const SizedBox(height: 24),

            _ContactsSwitcher(
              selectedIndex: _selectedList,
              onSelected: _selectList,
            ),

            const SizedBox(height: 22),

            AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _selectedList == 0
                  ? _buildClassmates()
                  : _buildTeachers(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassmates() {
    if (_isLoading) {
      return const _LoadingCard(
        key: ValueKey('classmates-loading'),
      );
    }

    if (_hasError) {
      return const _MessageCard(
        key: ValueKey('classmates-error'),
        icon: Icons.error_outline,
        text:
            'Не удалось загрузить одногруппников',
      );
    }

    if (_classmates.isEmpty) {
      return const _MessageCard(
        key: ValueKey('classmates-empty'),
        icon: Icons.group_outlined,
        text:
            'Одногруппники пока не найдены',
      );
    }

    return Column(
      key: const ValueKey('classmates'),
      children: _classmates.map(
        (profile) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: 10,
            ),
            child: _ContactListItem(
              name: profile.name,
              onTap: () =>
                  _openProfile(profile),
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _buildTeachers() {
    return const _MessageCard(
      key: ValueKey('teachers'),
      icon: Icons.school_outlined,
      text:
          'Преподаватели появятся здесь позже',
    );
  }
}

class _ContactsSwitcher extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ContactsSwitcher({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitcherButton(
              title: 'Одногруппники',
              icon: Icons.group_outlined,
              isSelected:
                  selectedIndex == 0,
              onTap: () =>
                  onSelected(0),
            ),
          ),

          const SizedBox(width: 4),

          Expanded(
            child: _SwitcherButton(
              title: 'Преподаватели',
              icon: Icons.school_outlined,
              isSelected:
                  selectedIndex == 1,
              onTap: () =>
                  onSelected(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitcherButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SwitcherButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppTheme.primaryBlue
          : Colors.transparent,
      borderRadius: BorderRadius.circular(
        AppTheme.smallRadius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppTheme.smallRadius,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : AppTheme.secondaryText,
              ),

              const SizedBox(width: 7),

              Flexible(
                child: Text(
                  title,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.secondaryText,
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

class _ContactListItem extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _ContactListItem({
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(
        AppTheme.cardRadius,
      ),
      child: InkWell(
        onTap: onTap,
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
                  color: AppTheme.primaryBlue
                      .withValues(
                    alpha: 0.15,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    AppTheme.smallRadius,
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 22,
                  color:
                      AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  name,
                  style:
                      AppTheme.cardTitle,
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color:
                    AppTheme.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 34,
      ),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MessageCard({
    super.key,
    required this.icon,
    required this.text,
  });

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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue
                  .withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(
                AppTheme.smallRadius,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color:
                  AppTheme.secondaryText,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              text,
              style:
                  AppTheme.secondaryBodyText,
            ),
          ),
        ],
      ),
    );
  }
}