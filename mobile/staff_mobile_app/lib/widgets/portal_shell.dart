import 'package:flutter/material.dart';

import '../utils/admin_theme.dart';

class PortalNavItem {
  const PortalNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDestructive;
}

class PortalSidebar extends StatelessWidget {
  const PortalSidebar({
    super.key,
    required this.items,
    this.footerLabel = 'ACCOUNT',
  });

  final List<PortalNavItem> items;
  final String footerLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final primaryItems = items.where((item) => !item.isDestructive).toList();
    final destructiveItems = items.where((item) => item.isDestructive).toList();

    return Container(
      color: colors.sidebar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...primaryItems.map((item) => _PortalSidebarNavItem(item: item)),
            const Spacer(),
            if (destructiveItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 10),
                child: Text(
                  footerLabel,
                  style: TextStyle(
                    color: colors.mutedText.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              ...destructiveItems.map(
                (item) => _PortalSidebarNavItem(item: item),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PortalTopBar extends StatelessWidget {
  const PortalTopBar({
    super.key,
    required this.onLogoTap,
    required this.onReportsTap,
    required this.onProfileTap,
    required this.departmentName,
    required this.userName,
    required this.notificationCount,
    this.portalLabel = 'Admin Portal',
  });

  final VoidCallback onLogoTap;
  final VoidCallback onReportsTap;
  final VoidCallback onProfileTap;
  final String departmentName;
  final String userName;
  final int notificationCount;
  final String portalLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colors.topBar,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onLogoTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(7),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'CityTrack PH',
            style: TextStyle(
              color: colors.isDark ? Colors.white : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            portalLabel,
            style: TextStyle(
              color: colors.isDark
                  ? Colors.white.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            departmentName,
            style: TextStyle(
              color: colors.isDark
                  ? Colors.white.withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: onReportsTap,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.isDark
                        ? const Color(0xFF1D2536)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Color(0xFFFBBF24),
                    size: 18,
                  ),
                ),
              ),
              if (notificationCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      notificationCount > 9 ? '9+' : '$notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: colors.isDark
                    ? const Color(0xFF1D2536)
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFF8B5CF6),
                    child: Text(
                      userName.isEmpty
                          ? 'A'
                          : userName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userName,
                    style: TextStyle(
                      color: colors.isDark ? Colors.white : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalSidebarNavItem extends StatelessWidget {
  const _PortalSidebarNavItem({required this.item});

  final PortalNavItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final activeColor = colors.activeText;
    final defaultColor = colors.isDark ? const Color(0xFFB8C0D4) : Colors.white;
    const destructiveColor = Color(0xFFF87171);
    final itemColor = item.isDestructive
        ? destructiveColor
        : (item.isActive ? activeColor : defaultColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: item.isActive ? colors.activeNav : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: itemColor, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: itemColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!item.isDestructive)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.isActive ? activeColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
