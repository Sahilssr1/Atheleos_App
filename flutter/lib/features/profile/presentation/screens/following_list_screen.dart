import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';

class FollowingListScreen extends ConsumerStatefulWidget {
  final String? userId;
  final String? userName;

  const FollowingListScreen({
    super.key,
    this.userId,
    this.userName,
  });

  @override
  ConsumerState<FollowingListScreen> createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends ConsumerState<FollowingListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _locallyUnfollowedIds = {};
  final Set<String> _locallyFollowedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleUnfollow(ProfileModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262626)),
        ),
        title: Text(
          'Unfollow @${user.username.isNotEmpty ? user.username : user.name}?',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Their posts and updates will no longer appear in your personal feed.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unfollow', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _locallyUnfollowedIds.add(user.id);
      _locallyFollowedIds.remove(user.id);
    });

    try {
      await ref.read(userRepositoryProvider).updateFollowState(user.id, false);
      ref.read(profileListProvider.notifier).loadAllProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfollowed ${user.name}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF141414),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppTheme.primaryColor,
              onPressed: () async {
                setState(() {
                  _locallyUnfollowedIds.remove(user.id);
                  _locallyFollowedIds.add(user.id);
                });
                await ref.read(userRepositoryProvider).updateFollowState(user.id, true);
                ref.read(profileListProvider.notifier).loadAllProfiles();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locallyUnfollowedIds.remove(user.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unfollow: $e')),
        );
      }
    }
  }

  Future<void> _handleFollowToggle(ProfileModel user, bool currentFollowing) async {
    final nextState = !currentFollowing;
    setState(() {
      if (nextState) {
        _locallyFollowedIds.add(user.id);
        _locallyUnfollowedIds.remove(user.id);
      } else {
        _locallyUnfollowedIds.add(user.id);
        _locallyFollowedIds.remove(user.id);
      }
    });

    try {
      await ref.read(userRepositoryProvider).updateFollowState(user.id, nextState);
      ref.read(profileListProvider.notifier).loadAllProfiles();
    } catch (e) {
      if (mounted) {
        setState(() {
          if (nextState) {
            _locallyFollowedIds.remove(user.id);
          } else {
            _locallyUnfollowedIds.remove(user.id);
          }
        });
      }
    }
  }

  void _showUserOptionsMenu(ProfileModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF262626)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white70),
                title: const Text('View Profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/profile/${user.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_off_outlined, color: Colors.white70),
                title: Text('Mute @${user.username}', style: const TextStyle(color: Colors.white)),
                subtitle: const Text('Hide their stories and posts quietly',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(settingsActionsProvider).muteUser(user.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Muted @${user.username}')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined, color: Colors.redAccent),
                title: Text('Block @${user.username}', style: const TextStyle(color: Colors.redAccent)),
                subtitle: const Text('They will not be able to find your profile or message you',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(settingsActionsProvider).blockUser(user.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Blocked @${user.username}')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedInId = ref.watch(loggedInUserIdProvider);
    final targetUserId = (widget.userId != null && widget.userId!.isNotEmpty)
        ? widget.userId!
        : loggedInId;
    final isMe = targetUserId == loggedInId || targetUserId.isEmpty;

    final followingIdsAsync = ref.watch(userFollowingIdsStreamProvider(targetUserId));
    final allProfiles = ref.watch(profileListProvider).valueOrNull ?? [];

    // Resolve followed profiles
    final streamIds = followingIdsAsync.valueOrNull ?? [];
    List<ProfileModel> followedUsers = [];

    if (streamIds.isNotEmpty) {
      // Map IDs from stream to full profiles
      for (final id in streamIds) {
        final profile = allProfiles.where((p) => p.id == id).firstOrNull;
        if (profile != null) {
          followedUsers.add(profile);
        } else {
          // Minimal fallback representation
          followedUsers.add(ProfileModel(
            id: id,
            name: 'User $id',
            username: id,
            avatarUrl: '',
            coverUrl: '',
            role: 'Athlete',
            verified: false,
            sport: '',
            primaryPosition: '',
            clubOrAcademy: '',
            city: '',
            state: '',
            bio: '',
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            clipsCount: 0,
            achievements: const [],
            certifications: const [],
            website: '',
            socialLinks: const {},
            mediaGallery: const [],
          ));
        }
      }
    }

    // Apply local optimistic overrides
    if (isMe) {
      followedUsers = followedUsers
          .where((u) => !_locallyUnfollowedIds.contains(u.id))
          .toList();
    }

    // Filter by search query
    final filteredUsers = followedUsers.where((user) {
      if (_query.isEmpty) return true;
      final searchable =
          '${user.name} ${user.username} ${user.sport} ${user.primaryPosition} ${user.role} ${user.clubOrAcademy}'
              .toLowerCase();
      return searchable.contains(_query);
    }).toList();

    final screenTitle = isMe
        ? 'FOLLOWING'
        : ((widget.userName != null && widget.userName!.isNotEmpty)
            ? '${widget.userName!.toUpperCase()}\'S FOLLOWING'
            : 'FOLLOWING');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              screenTitle,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${followedUsers.length}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Search Bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: isMe ? 'Search accounts you follow...' : 'Search following...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                ),
              ),
            ),
          ),

          // ── User List ────────────────────────────────────────────────────
          Expanded(
            child: followingIdsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
              error: (err, _) => Center(
                child: Text('Error loading followings: $err',
                    style: const TextStyle(color: Colors.white54)),
              ),
              data: (_) {
                if (followedUsers.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.people_outline,
                    title: isMe
                        ? 'Not following anyone yet'
                        : 'No followed accounts',
                    subtitle: isMe
                        ? 'Accounts you follow will appear here privately so you can manage them at any time.'
                        : 'This user is not currently following any accounts.',
                  );
                }

                if (filteredUsers.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching accounts',
                    subtitle: 'We couldn\'t find any followed users matching "$_query".',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _buildUserTile(user, isMe, loggedInId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(ProfileModel user, bool isMe, String loggedInId) {
    final isFollowingUser = _locallyFollowedIds.contains(user.id) ||
        (user.isFollowing && !_locallyUnfollowedIds.contains(user.id));

    return InkWell(
      onTap: () => context.push('/profile/${user.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF141414),
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                if (user.verified)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: AppTheme.primaryColor,
                        size: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name.isNotEmpty ? user.name : 'Atheleos User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '@${user.username.isNotEmpty ? user.username : user.id}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      if (user.sport.isNotEmpty || user.role.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.sport.isNotEmpty ? user.sport : user.role,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Action: Unfollow / Follow
            if (isMe)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                ),
                onPressed: () => _handleUnfollow(user),
                child: Text(
                  'Unfollow',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (user.id != loggedInId)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: isFollowingUser
                      ? const Color(0xFF1E1E1E)
                      : AppTheme.primaryColor,
                  foregroundColor: isFollowingUser ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _handleFollowToggle(user, isFollowingUser),
                child: Text(
                  isFollowingUser ? 'Following' : 'Follow',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // 3-dots Context Menu
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
              onPressed: () => _showUserOptionsMenu(user),
              visualDensity: VisualDensity.compact,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Icon(icon, color: Colors.white38, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
