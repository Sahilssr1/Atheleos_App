import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../controllers/profile_controller.dart';
import '../../../chat/presentation/widgets/share_content_bottom_sheet.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

void showProfileShareDialog(BuildContext context, ProfileModel profile, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) {
      final profileLink = 'https://atheleos.social/profile/${profile.username}';
      return AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          'SHARE ${profile.role.toUpperCase()} PROFILE',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.primaryColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this profile link or send it directly to a chat.',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      profileLink,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(AthIcons.documentDuplicate, size: 16, color: AppTheme.primaryColor),
                    onPressed: () {
                      try {
                        ref.read(userRepositoryProvider).incrementPortfolioShares(profile.id);
                      } catch (_) {}
                      Clipboard.setData(ClipboardData(text: profileLink));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile link copied to clipboard!'),
                          backgroundColor: AppTheme.primaryColor,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(AthIcons.chatRound, size: 16),
                label: const Text('SHARE TO DIRECT MESSAGE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    builder: (context) => ShareContentBottomSheet(
                      userId: profile.id,
                      shareType: 'profile',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white60)),
          ),
        ],
      );
    },
  );
}
