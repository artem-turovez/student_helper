import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            32,
            AppTheme.screenPadding,
            28,
          ),
          child: Column(
            children: [
              const Spacer(),

              Image.asset(
                AppBrand.logoPath,
                width: 150,
                height: 105,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 30),

              const Text(
                AppBrand.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                AppBrand.collegeName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryText,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(
                    AppTheme.cardRadius,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _FeatureIcon(
                      icon: Icons.school_outlined,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Расписание, события, контакты '
                        'и учебная информация всегда '
                        'под рукой.',
                        style:
                            AppTheme.secondaryBodyText,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text('Войти'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const RegisterScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        AppTheme.primaryText,
                    side: const BorderSide(
                      color: AppTheme.primaryBlue,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        AppTheme.cardRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Создать аккаунт',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                AppBrand.collegeShortName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;

  const _FeatureIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        size: 22,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}