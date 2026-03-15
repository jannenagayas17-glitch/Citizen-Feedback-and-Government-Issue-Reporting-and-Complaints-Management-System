import 'dart:ui';

import 'package:flutter/material.dart';

import '../../utils/auth_redirect.dart';
import '../../utils/app_routes.dart';
import '../../utils/token_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));

    final token = await TokenStorage.getToken();
    final role = (await TokenStorage.getRole())?.trim().toLowerCase();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AuthRedirect.routeForRole(role),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0C1727),
                  Color(0xFF1E293B),
                  Color(0xFF463327),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -40,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFF2563EB).withOpacity(0.18),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -30,
            child: _GlowOrb(
              size: 210,
              color: const Color(0xFFD8B15A).withOpacity(0.16),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.20),
                            Colors.white.withOpacity(0.08),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.24),
                            blurRadius: 28,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final scale = 1 + (_pulseController.value * 0.05);
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: const Color(0xFFD8B15A),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD8B15A)
                                        .withOpacity(0.22),
                                    blurRadius: 28,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Tacloban City Engineering\nOffice',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Citizen Feedback & Reports System',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                              ),
                            ),
                            child: Text(
                              'Preparing secure access',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.78),
                                fontSize: 13,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _LoadingDots(),
                        ],
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

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final progress = ((_controller.value - (index * 0.2)) % 1.0);
            final opacity = 0.35 + (0.65 * (1 - (progress - 0.5).abs() * 2));
            final scale = 0.8 + (0.35 * (1 - (progress - 0.5).abs() * 2));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale.clamp(0.8, 1.15),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(opacity.clamp(0.35, 1.0)),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
