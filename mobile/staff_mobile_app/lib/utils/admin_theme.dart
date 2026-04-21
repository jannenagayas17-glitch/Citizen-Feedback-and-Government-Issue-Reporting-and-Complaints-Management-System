import 'package:flutter/material.dart';

class AdminThemeColors {
  const AdminThemeColors({
    required this.isDark,
    required this.background,
    required this.backgroundGradient,
    required this.sidebarGradient,
    required this.topBarGradient,
    required this.sidebar,
    required this.topBar,
    required this.panel,
    required this.panelAlt,
    required this.input,
    required this.border,
    required this.text,
    required this.mutedText,
    required this.activeNav,
    required this.activeText,
    required this.primary,
    required this.warningSurface,
    required this.warningBorder,
  });

  final bool isDark;
  final Color background;
  final List<Color> backgroundGradient;
  final List<Color> sidebarGradient;
  final List<Color> topBarGradient;
  final Color sidebar;
  final Color topBar;
  final Color panel;
  final Color panelAlt;
  final Color input;
  final Color border;
  final Color text;
  final Color mutedText;
  final Color activeNav;
  final Color activeText;
  final Color primary;
  final Color warningSurface;
  final Color warningBorder;

  static AdminThemeColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return AdminThemeColors(
        isDark: true,
        background: const Color(0xFF0C1727),
        backgroundGradient: const [
          Color(0xFF0C1727),
          Color(0xFF1A2940),
          Color(0xFF463327),
        ],
        sidebarGradient: const [Color(0xFF101423), Color(0xFF0B1020)],
        topBarGradient: const [Color(0xFF111625), Color(0xFF101423)],
        sidebar: const Color(0xFF101423),
        topBar: const Color(0xFF111625),
        panel: const Color(0xFF151A2E),
        panelAlt: const Color(0xFF111426),
        input: const Color(0xFF181C2E),
        border: Colors.white.withValues(alpha: 0.07),
        text: Colors.white,
        mutedText: Colors.white.withValues(alpha: 0.62),
        activeNav: const Color(0xFF243455),
        activeText: const Color(0xFFF0A43B),
        primary: const Color(0xFF2563EB),
        warningSurface: const Color(0xFF2C2018),
        warningBorder: const Color(0xFF6F4D2C),
      );
    }

    return AdminThemeColors(
      isDark: false,
      background: const Color(0xFFF5F8FC),
      backgroundGradient: const [
        Color(0xFFF8FBFF),
        Color(0xFFEFF6FF),
        Color(0xFFE8F0FF),
      ],
      sidebarGradient: const [
        Color(0xFF0F4FB8),
        Color(0xFF1D7BEA),
        Color(0xFF42A5F5),
      ],
      topBarGradient: const [
        Color(0xFF0B4AA7),
        Color(0xFF1E88E5),
        Color(0xFF5BB8FF),
      ],
      sidebar: const Color(0xFF0F4FB8),
      topBar: const Color(0xFF0B4AA7),
      panel: Colors.white,
      panelAlt: const Color(0xFFF8FBFF),
      input: const Color(0xFFF1F5F9),
      border: const Color(0xFFD6E3F3),
      text: const Color(0xFF0F172A),
      mutedText: const Color(0xFF64748B),
      activeNav: const Color(0xFFD9E9FF),
      activeText: const Color(0xFFF97316),
      primary: const Color(0xFF2563EB),
      warningSurface: const Color(0xFFFFF7ED),
      warningBorder: const Color(0xFFF59E0B),
    );
  }
}
