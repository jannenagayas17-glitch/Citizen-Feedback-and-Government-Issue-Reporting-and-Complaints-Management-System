import 'package:flutter/material.dart';

import '../services/citizen_avatar_service.dart';

class CitizenAvatar extends StatelessWidget {
  const CitizenAvatar({
    super.key,
    required this.name,
    required this.size,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.borderWidth = 0,
    this.fontSize,
  });

  final String name;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final double borderWidth;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CitizenAvatarService.revision,
      builder: (context, _, _) {
        final avatarUrl = CitizenAvatarService.cachedAvatarUrl;
        final initial = name.trim().isEmpty
            ? 'C'
            : name.trim()[0].toUpperCase();

        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: borderWidth),
          ),
          child: ClipOval(
            child: avatarUrl == null
                ? _InitialAvatar(
                    initial: initial,
                    textColor: textColor,
                    fontSize: fontSize ?? (size * 0.46),
                  )
                : Image.network(
                    avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _InitialAvatar(
                      initial: initial,
                      textColor: textColor,
                      fontSize: fontSize ?? (size * 0.46),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({
    required this.initial,
    required this.textColor,
    required this.fontSize,
  });

  final String initial;
  final Color textColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
