import 'package:flutter/material.dart';

import '../utils/app_theme_controller.dart';

class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({
    super.key,
    this.compact = false,
    this.darkBackground,
    this.lightBackground,
  });

  final bool compact;
  final Color? darkBackground;
  final Color? lightBackground;

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = controller.isDarkMode;
        final backgroundColor = isDark
            ? darkBackground ?? const Color(0xFF17223A)
            : lightBackground ?? Colors.white;
        final foregroundColor = isDark
            ? const Color(0xFFEFF6FF)
            : const Color(0xFF172554);

        return Tooltip(
          message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            child: InkWell(
              onTap: () => controller.setDarkMode(!isDark),
              borderRadius: BorderRadius.circular(compact ? 18 : 22),
              child: Container(
                height: compact ? 34 : 44,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(compact ? 18 : 22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFD8E3F7),
                  ),
                  boxShadow: isDark
                      ? const []
                      : [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: foregroundColor,
                      size: compact ? 17 : 20,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Text(
                        isDark ? 'Dark' : 'Light',
                        style: TextStyle(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
