import 'package:flutter/material.dart';

class CitizenBottomNav extends StatelessWidget {
  const CitizenBottomNav({
    super.key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onReportsTap,
    required this.onAlertsTap,
    required this.onProfileTap,
  });

  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onReportsTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return BottomAppBar(
      color: isDark ? const Color(0xFF101827) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: isDark ? 0 : 12,
      child: SizedBox(
        height: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _CitizenNavItem(
              icon: Icons.home_filled,
              label: 'Home',
              selected: currentIndex == 0,
              color: const Color(0xFF3B82F6),
              inactiveColor: isDark
                  ? const Color(0xFF7B86A1)
                  : const Color(0xFF64748B),
              onTap: onHomeTap,
            ),
            _CitizenNavItem(
              icon: Icons.description_outlined,
              label: 'Reports',
              selected: currentIndex == 1,
              color: const Color(0xFF3B82F6),
              inactiveColor: isDark
                  ? const Color(0xFF7B86A1)
                  : const Color(0xFF64748B),
              onTap: onReportsTap,
            ),
            const SizedBox(width: 56),
            _CitizenNavItem(
              icon: Icons.notifications_active_outlined,
              label: 'Alerts',
              selected: currentIndex == 3,
              color: const Color(0xFF3B82F6),
              inactiveColor: isDark
                  ? const Color(0xFF7B86A1)
                  : const Color(0xFF64748B),
              onTap: onAlertsTap,
            ),
            _CitizenNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: currentIndex == 4,
              color: const Color(0xFF3B82F6),
              inactiveColor: isDark
                  ? const Color(0xFF7B86A1)
                  : const Color(0xFF64748B),
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CitizenNavItem extends StatelessWidget {
  const _CitizenNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? color : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: selected ? color : inactiveColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
