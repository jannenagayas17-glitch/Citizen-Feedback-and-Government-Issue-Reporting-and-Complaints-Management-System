import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/citizen_app_theme.dart';
import '../utils/citizen_theme_colors.dart';

class CitizenAuthScaffold extends StatelessWidget {
  const CitizenAuthScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CitizenAppTheme.dark(),
      child: Builder(
        builder: (context) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: citizenPageGradient(context),
                  ),
                ),
                Positioned(
                  left: -40,
                  top: 70,
                  child: _GlowBlob(
                    color: CitizenAppPalette.mauve.withValues(alpha: 0.30),
                  ),
                ),
                Positioned(
                  right: -56,
                  bottom: 96,
                  child: _GlowBlob(
                    color: CitizenAppPalette.taupe.withValues(alpha: 0.26),
                  ),
                ),
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/Tacloban_City_bg.png',
                        fit: BoxFit.cover,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: citizenAuthOverlayColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: padding.add(
                        EdgeInsets.only(bottom: bottomInset + 16),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CitizenAuthCard extends StatelessWidget {
  const CitizenAuthCard({
    super.key,
    required this.child,
    this.maxWidth = 392,
    this.padding = const EdgeInsets.fromLTRB(22, 26, 22, 24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: citizenGlassBorderColor(context)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                citizenGlassSurfaceColor(context),
                citizenGlassSurfaceColor(
                  context,
                ).withValues(alpha: citizenIsDark(context) ? 0.18 : 0.76),
              ],
            ),
            boxShadow: citizenCardShadow(context),
          ),
          child: child,
        ),
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
