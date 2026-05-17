import 'package:flutter/material.dart';

import '../utils/app_theme_controller.dart';
import '../utils/citizen_theme_colors.dart';

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
            ? darkBackground ?? citizenCardColor(context)
            : lightBackground ?? Colors.white;
        final foregroundColor = isDark
            ? CitizenAppPalette.sand
            : CitizenAppPalette.navy;

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
                padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(compact ? 18 : 22),
                  border: Border.all(color: citizenBorderColor(context)),
                  boxShadow: isDark
                      ? const []
                      : [
                          BoxShadow(
                            color: CitizenAppPalette.navy.withValues(
                              alpha: 0.08,
                            ),
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
