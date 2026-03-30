import 'dart:convert';
import 'dart:typed_data';

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
    return FutureBuilder<String?>(
      future: CitizenAvatarService.getAvatarBase64(),
      builder: (context, snapshot) {
        final avatarBase64 = snapshot.data;
        final imageBytes = _decodeImageBytes(avatarBase64);
        final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: borderColor == null
                ? null
                : Border.all(
                    color: borderColor!,
                    width: borderWidth,
                  ),
            image: imageBytes == null
                ? null
                : DecorationImage(
                    image: MemoryImage(imageBytes),
                    fit: BoxFit.cover,
                  ),
          ),
          child: imageBytes == null
              ? Text(
                  initial,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize ?? (size * 0.46),
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        );
      },
    );
  }

  Uint8List? _decodeImageBytes(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}
