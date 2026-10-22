import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/chat_list_controller.dart';
import '../controllers/chat_controller.dart';
import '../widgets/create_group_bottom_sheet.dart';
import '../../../profile/domain/models/profile_model.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

enum _ChatInboxTab { chats, requests }

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ChatInboxTab _selectedTab = _ChatInboxTab.chats;

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required int badgeCount,
    required VoidCallback onTap,
    bool isRequestTab = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1E1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isRequestTab && badgeCount > 0
                    ? AppTheme.primaryColor.withValues(alpha: 0.6)
                    : const Color(0xFF333333))
                : const Color(0xFF222222),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isRequestTab ? AppTheme.primaryColor : const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: TextStyle(
                    color: isRequestTab ? Colors.black : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  void _showNewDMModal(BuildContext context, List<ProfileModel> profiles, String myId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF262626), width: 1),
      ),
      isScrollControlled: true,
      builder: (context) {
        final availableProfiles = profiles.where((p) => p.id != myId).toList();
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'New Direct Message',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableProfiles.length,
                    itemBuilder: (context, index) {
                      final user = availableProfiles[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage: (user.avatarUrl.isNotEmpty && (user.avatarUrl.startsWith('http://') || user.avatarUrl.startsWith('https://')))
                              ? NetworkImage(user.avatarUrl)
                              : null,
                          backgroundColor: Colors.white10,
                          child: (user.avatarUrl.isEmpty || (!user.avatarUrl.startsWith('http://') && !user.avatarUrl.startsWith('https://')))
                              ? const Icon(AthIcons.userSolid, size: 20, color: Colors.white54)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (user.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                AthIcons.checkBadgeSolid,
                                color: Colors.blue,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${user.role} • ${user.sport}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          AthIcons.chevronRight,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          context.push('/chat/room?receiverId=${user.id}');
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(loggedInUserIdProvider);
    final chatRooms = ref.watch(chatListProvider);
    final isLoading = ref.watch(chatListLoadingProvider);
    final profilesAsync = ref.watch(profileListProvider);

    // Pre-warm the top 5 most recent chat rooms in the background so opening any conversation is 0ms instant!
    if (chatRooms.isNotEmpty) {
      Future.microtask(() {
        for (final room in chatRooms.take(5)) {
          ref.read(roomChatProvider(room.id));
        }
      });
    }

    final profiles = profilesAsync.maybeWhen(
      data: (data) => data,
      orElse: () => <ProfileModel>[],
    );

    ProfileModel? findProfile(String id) {
      try {
        return profiles.firstWhere((p) => p.id == id || p.username == id);
      } catch (_) {
        return null;
      }
    }

    final allPrimaryRooms = chatRooms.where((r) => !r.isMessageRequestFor(myId)).toList();
    final allRequestRooms = chatRooms.where((r) => r.isMessageRequestFor(myId)).toList();

    final currentPool = _selectedTab == _ChatInboxTab.chats ? allPrimaryRooms : allRequestRooms;

    // Filter active chat rooms matching search criteria
    final filteredRooms = currentPool.where((room) {
      if (room.isGroup) {
        final matchName = (room.name ?? 'Group Chat').toLowerCase().contains(_searchQuery.toLowerCase());
        final matchMsg = room.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchName || matchMsg;
      }
      final otherId = room.participantIds.firstWhere((id) => id != myId, orElse: () => '');
      final otherProfile = findProfile(otherId);
      final otherName = (otherProfile?.name.isNotEmpty == true)
          ? otherProfile!.name
          : (otherProfile?.username.isNotEmpty == true ? '@${otherProfile!.username}' : 'Athlete');

      final matchName = otherName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchMsg = room.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchName || matchMsg;
    }).toList();

    final isProfilesLoading = profilesAsync.isLoading || !profilesAsync.hasValue;
    final isAwaitingProfiles = chatRooms.isNotEmpty && (isProfilesLoading || profiles.isEmpty);

    final Widget listContent;
    if (isLoading || isAwaitingProfiles) {
      listContent = const _ChatListShimmerLoading();
    } else if (filteredRooms.isEmpty) {
      if (_selectedTab == _ChatInboxTab.requests) {
        listContent = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF262626), width: 1),
                ),
                child: const Icon(
                  AthIcons.envelope,
                  color: Colors.white54,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? 'No message requests found' : 'No Message Requests',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'No message requests match "$_searchQuery"'
                      : 'When someone you haven\'t chatted with sends you a message, it will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        listContent = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF262626), width: 1),
                ),
                child: const Icon(
                  AthIcons.chatRound,
                  color: Colors.white54,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? 'No conversations found' : 'No conversations yet',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a conversation or create a group chat!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showNewDMModal(context, profiles, myId),
                    icon: const Icon(AthIcons.plus, color: Colors.black, size: 18),
                    label: const Text(
                      'Start Chat',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => CreateGroupBottomSheet.show(context, profiles, myId),
                    icon: const Icon(AthIcons.userGroup, color: AppTheme.primaryColor, size: 18),
                    label: const Text(
                      'New Group',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } else {
      listContent = ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: filteredRooms.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Colors.white10,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final room = filteredRooms[index];
                      final isGroup = room.isGroup;

                      final otherId = room.participantIds.firstWhere((id) => id != myId, orElse: () => '');
                      final otherProfile = findProfile(otherId);

                      final name = isGroup
                          ? (room.name?.isNotEmpty == true ? room.name! : 'Group Chat')
                          : (otherProfile?.name ?? 'Atheleos User');
                      final avatarUrl = isGroup
                          ? (room.iconUrl ?? '')
                          : (otherProfile?.avatarUrl ?? '');
                      final isVerified = !isGroup && (otherProfile?.verified ?? false);
                      final hasUnread = room.unreadBy.contains(myId);

                      return Dismissible(
                        key: Key(room.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            AthIcons.trash,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          final isRequest = room.isMessageRequestFor(myId);
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF121212),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFF262626)),
                              ),
                              title: Text(
                                isGroup
                                    ? 'Leave or delete group?'
                                    : (isRequest ? 'Delete message request?' : 'Delete chat?'),
                                style: const TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                isGroup
                                    ? 'This will remove this group conversation from your inbox.'
                                    : (isRequest
                                        ? 'This will remove this message request from your inbox.'
                                        : 'This will delete the conversation from your inbox.'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(isGroup ? 'Leave' : 'Delete', style: const TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          if (isGroup) {
                            ref.read(chatRepositoryProvider).leaveGroup(room.id, myId);
                          } else {
                            ref.read(chatListProvider.notifier).deleteChatRoom(room.id);
                          }
                        },
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (isGroup) {
                              context.push('/chat/room?roomId=${room.id}');
                            } else {
                              context.push('/chat/room?receiverId=$otherId&roomId=${room.id}');
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              children: [
                                if (isGroup)
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4), width: 1.5),
                                    ),
                                    child: CircleAvatar(
                                      radius: 25,
                                      backgroundImage: (avatarUrl.isNotEmpty &&
                                              (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      onBackgroundImageError: (_, __) {},
                                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                      child: (avatarUrl.isEmpty ||
                                              (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')))
                                          ? const Icon(AthIcons.userGroup, size: 26, color: AppTheme.primaryColor)
                                          : null,
                                    ),
                                  )
                                else
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundImage: (avatarUrl.isNotEmpty &&
                                            (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    onBackgroundImageError: (_, __) {},
                                    backgroundColor: Colors.white10,
                                    child: (avatarUrl.isEmpty ||
                                            (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')))
                                        ? const Icon(AthIcons.userSolid, size: 26, color: Colors.white54)
                                        : null,
                                  ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                                                fontSize: 15.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isGroup) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${room.participantIds.length} members',
                                                style: const TextStyle(
                                                  color: AppTheme.primaryColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ] else if (room.isMessageRequestFor(myId)) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Request',
                                                style: TextStyle(
                                                  color: AppTheme.primaryColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ] else if (isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(
                                              AthIcons.checkBadgeSolid,
                                              color: Colors.blue,
                                              size: 14,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        room.lastMessage.isNotEmpty ? room.lastMessage : (isGroup ? 'Group created' : 'No messages'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: hasUnread ? Colors.white : Colors.white60,
                                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatTimestamp(room.lastMessageTimestamp),
                                      style: TextStyle(
                                        color: hasUnread ? AppTheme.primaryColor : Colors.white30,
                                        fontSize: 11.5,
                                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (hasUnread)
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryColor.withValues(alpha: 0.6),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
    }



    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(AthIcons.arrowLeft, color: Colors.white, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AthIcons.userPlus, color: AppTheme.primaryColor, size: 20),
              ),
              tooltip: 'New Group',
              onPressed: () {
                HapticFeedback.lightImpact();
                CreateGroupBottomSheet.show(context, profiles, myId);
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF262626), width: 1),
                ),
                child: const Icon(AthIcons.pencilSquare, color: Colors.white, size: 22),
              ),
              tooltip: 'New Direct Message',
              onPressed: () {
                HapticFeedback.lightImpact();
                _showNewDMModal(context, profiles, myId);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF262626), width: 1),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search chats & conversations...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(AthIcons.search, color: Colors.white38, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(AthIcons.xMark, color: Colors.white38, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
          ),

          // Inbox Tabs: Chats vs Message Requests
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Chats',
                    isSelected: _selectedTab == _ChatInboxTab.chats,
                    badgeCount: allPrimaryRooms.where((r) => r.unreadBy.contains(myId)).length,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTab = _ChatInboxTab.chats);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(
                    label: 'Requests',
                    isSelected: _selectedTab == _ChatInboxTab.requests,
                    badgeCount: allRequestRooms.length,
                    isRequestTab: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTab = _ChatInboxTab.requests);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Quick Notice Banner on Chats tab if pending requests exist
          if (_selectedTab == _ChatInboxTab.chats && allRequestRooms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedTab = _ChatInboxTab.requests);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(AthIcons.envelope, color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            allRequestRooms.length == 1
                                ? '1 pending message request'
                                : '${allRequestRooms.length} pending message requests',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Text(
                          'View',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(AthIcons.chevronRight, color: AppTheme.primaryColor, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Chat Rooms list
          Expanded(
            child: listContent,
          ),
        ],
      ),
    );
  }
}

class _ChatListShimmerLoading extends StatefulWidget {
  const _ChatListShimmerLoading();

  @override
  State<_ChatListShimmerLoading> createState() => _ChatListShimmerLoadingState();
}

class _ChatListShimmerLoadingState extends State<_ChatListShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: 7,
            separatorBuilder: (_, index) => index == 0 ? const SizedBox.shrink() : const Divider(color: Colors.white10, height: 1, indent: 76),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  child: Center(
                    child: Text(
                      'Loading chats for the first time may take some time...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFF181818),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 130,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF181818),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 200,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFF181818),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 35,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
