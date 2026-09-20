import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A universal avatar widget that displays a user's profile image if present,
/// or a clean, modern user icon placeholder when no profile image has been added.
/// Prevents any dummy/mock profile pictures from showing.
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? name;
  final String? role;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.name,
    this.role,
    this.backgroundColor,
    this.iconColor,
    this.onTap,
  });

  bool get _hasValidUrl {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  IconData get _placeholderIcon {
    final normalizedRole = role?.trim().toLowerCase() ?? '';
    if (normalizedRole == 'brand') {
      return Icons.business_outlined;
    } else if (normalizedRole == 'federation') {
      return Icons.account_balance_outlined;
    } else if (normalizedRole == 'coach') {
      return Icons.sports_outlined;
    }
    return Icons.person_outline;
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFF1E293B);
    final fg = iconColor ?? Colors.white38;

    Widget avatar;
    if (_hasValidUrl) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: CachedNetworkImageProvider(
          imageUrl!.trim(),
          maxWidth: (radius * 3).toInt(),
          maxHeight: (radius * 3).toInt(),
        ),
        child: null,
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Icon(
          _placeholderIcon,
          size: radius * 1.1,
          color: fg,
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
