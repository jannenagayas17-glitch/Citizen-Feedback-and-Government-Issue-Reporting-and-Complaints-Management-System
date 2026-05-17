import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/citizen_auth_gate.dart';
import '../../services/citizen_avatar_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/auth_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme_controller.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../utils/token_storage.dart';
import '../../widgets/citizen_auth_scaffold.dart';
import '../../widgets/citizen_branding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.authService,
    this.bootstrapDelay = const Duration(milliseconds: 1400),
  });

  final AuthService? authService;
  final Duration bootstrapDelay;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _bootstrapTimer;

  @override
  void initState() {
    super.initState();
    _bootstrapTimer = Timer(widget.bootstrapDelay, _bootstrap);
  }

  Future<void> _bootstrap() async {
    try {
      final result = await CitizenAuthGate(
        authService: widget.authService,
      ).resolve().timeout(const Duration(seconds: 6));

      if (result.shouldClearStoredSession) {
        await _clearLocalSession();
      }

      if (!mounted) return;

      if (!result.shouldOpenCitizenHome) {
        _goTo(AppRoutes.login);
        return;
      }

      await AppThemeScope.of(context).loadForUser(result.user!);
      if (mounted) {
        _goTo(AppRoutes.citizenHome);
      }
    } catch (_) {
      await _clearLocalSession();
      if (mounted) {
        _goTo(AppRoutes.login);
      }
    }
  }

  Future<void> _clearLocalSession() async {
    await TokenStorage.clearAll();
    CitizenDataCache.clear();
    await CitizenAvatarService.clearAvatar();
  }

  void _goTo(String route) {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  @override
  void dispose() {
    _bootstrapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CitizenAuthScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1.0),
        duration: const Duration(milliseconds: 950),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          final opacity = (((scale - 0.9) / 0.1).clamp(0.0, 1.0)).toDouble();
          return Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CitizenLogoBadge(size: 148),
              const SizedBox(height: 28),
              Text(
                'Citizen Feedback',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.98),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tacloban City reports, complaints, and civic service updates in one secure place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CitizenAppPalette.sand.withValues(alpha: 0.88),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: citizenInfoSurfaceColor(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: citizenInfoBorderColor(context)),
                ),
                child: Text(
                  'Preparing secure citizen access',
                  style: TextStyle(
                    color: citizenInfoTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CitizenAppPalette.sand,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your workspace...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CitizenAppPalette.sand.withValues(alpha: 0.82),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Dot(),
                  SizedBox(width: 10),
                  _Dot(),
                  SizedBox(width: 10),
                  _Dot(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: CitizenAppPalette.sand.withValues(alpha: 0.92),
        shape: BoxShape.circle,
      ),
    );
  }
}
