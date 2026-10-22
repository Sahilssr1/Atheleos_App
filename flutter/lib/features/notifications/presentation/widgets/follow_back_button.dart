import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/controllers/settings_controller.dart';
import '../../data/notification_service.dart';
import '../../domain/models/notification_model.dart';
import '../controllers/notifications_controller.dart';
import '../../../../core/utils/user_facing_error.dart';

class FollowBackButton extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String notificationId;
  final bool isNotificationRead;
  final ValueChanged<bool>? onFollowChanged;

  const FollowBackButton({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.notificationId,
    required this.isNotificationRead,
    this.onFollowChanged,
  });

  @override
  ConsumerState<FollowBackButton> createState() => _FollowBackButtonState();
}

class _FollowBackButtonState extends ConsumerState<FollowBackButton> {
  bool? _optimisticFollowing;
  bool _isLoading = false;

  Future<void> _handleFollowBack() async {
    if (_isLoading) return;

    HapticFeedback.lightImpact();
    setState(() {
      _optimisticFollowing = true;
      _isLoading = true;
    });
    widget.onFollowChanged?.call(true);

    try {
      final myId = ref.read(loggedInUserIdProvider);
      final effectiveMyId = myId.isNotEmpty
          ? myId
          : (FirebaseAuth.instance.currentUser?.uid ?? '');

      await ref
          .read(userRepositoryProvider)
          .updateFollowState(widget.targetUserId, true);

      // Auto-mark the follow notification as read upon following back
      if (!widget.isNotificationRead && widget.notificationId.isNotEmpty) {
        ref.read(notificationsProvider.notifier).markAsRead(widget.notificationId);
      }

      // Send reciprocal follow notification
      if (effectiveMyId.isNotEmpty) {
        final me = ref.read(currentUserProvider).valueOrNull;
        unawaited(NotificationService.instance.follow(
          receiverId: widget.targetUserId,
          actor: NotificationActor(
            id: effectiveMyId,
            name: me?.name ?? 'Someone',
            avatar: me?.avatarUrl ?? '',
          ),
        ));
      }

      ref.read(profileListProvider.notifier).loadAllProfiles();
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticFollowing = false;
        });
        widget.onFollowChanged?.call(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e, fallback: 'Failed to follow. Please try again.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleUnfollow(String displayName) async {
    if (_isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262626)),
        ),
        title: Text(
          'Unfollow @$displayName?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Their posts and updates will no longer appear in your personal feed.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unfollow', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.lightImpact();
    setState(() {
      _optimisticFollowing = false;
      _isLoading = true;
    });
    widget.onFollowChanged?.call(false);

    try {
      await ref
          .read(userRepositoryProvider)
          .updateFollowState(widget.targetUserId, false);

      ref.read(profileListProvider.notifier).loadAllProfiles();
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticFollowing = true;
        });
        widget.onFollowChanged?.call(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e, fallback: 'Failed to unfollow. Please try again.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(loggedInUserIdProvider);
    final effectiveMyId = myId.isNotEmpty
        ? myId
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    // Never show follow button for oneself or invalid system users
    if (widget.targetUserId.isEmpty ||
        widget.targetUserId == 'system' ||
        (effectiveMyId.isNotEmpty && widget.targetUserId == effectiveMyId)) {
      return const SizedBox.shrink();
    }

    // Determine follow state via stream and fallback caches
    final streamFollowing =
        ref.watch(isUserFollowingStreamProvider(widget.targetUserId)).valueOrNull;
    final followingIdsList =
        ref.watch(followingUsersStreamProvider).valueOrNull;
    final profileListFollowing = ref
        .watch(profileListProvider)
        .valueOrNull
        ?.where((p) => p.id == widget.targetUserId)
        .firstOrNull
        ?.isFollowing;

    final isFollowing = _optimisticFollowing ??
        streamFollowing ??
        (followingIdsList?.contains(widget.targetUserId)) ??
        profileListFollowing ??
        false;

    final displayName = widget.targetUserName.isNotEmpty
        ? widget.targetUserName
        : widget.targetUserId;

    if (isFollowing) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: Color(0xFF262626), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
        onPressed: _isLoading ? null : () => _handleUnfollow(displayName),
        child: _isLoading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              )
            : Text(
                'Following',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _isLoading ? null : _handleFollowBack,
      child: _isLoading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
          : Text(
              'Follow back',
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
