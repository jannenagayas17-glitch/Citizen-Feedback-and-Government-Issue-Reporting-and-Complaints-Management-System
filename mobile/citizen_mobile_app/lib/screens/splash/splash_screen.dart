import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/citizen_auth_gate.dart';
import '../../services/citizen_avatar_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/auth_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme_controller.dart';
import '../../utils/token_storage.dart';

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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B1729),
                  Color(0xFF162844),
                  Color(0xFF4B3529),
                ],
              ),
            ),
          ),
          Positioned(
            left: -60,
            top: 90,
            child: _GlowBlob(color: Color(0xFF2563EB).withValues(alpha: 0.22)),
          ),
          Positioned(
            right: -50,
            bottom: 110,
            child: _GlowBlob(color: Color(0xFFD8B15A).withValues(alpha: 0.18)),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/images/logo_splash.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, scale, child) {
                    final opacity = (((scale - 0.92) / 0.08).clamp(
                      0.0,
                      1.0,
                    )).toDouble();
                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(scale: scale, child: child),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 360),
                        padding: const EdgeInsets.fromLTRB(26, 34, 26, 28),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.10),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 28,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 108,
                              height: 108,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: const Color(0xFFD8B15A),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFD8B15A,
                                    ).withValues(alpha: 0.18),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/logo_splash.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'CityTrack',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tacloban City Citizen Feedback',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: Text(
                                'Preparing secure access',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
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
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
    );
  }
}
