import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/upload_queue_coordinator.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_room_model.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/controllers/settings_controller.dart';
import '../../../clips/presentation/screens/clips_screen.dart' show ReelsViewerScreen;
import '../controllers/chat_controller.dart';
import '../controllers/chat_theme_controller.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

class SharedContentScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String receiverId;

  const SharedContentScreen({
    super.key,
    required this.roomId,
    this.receiverId = '',
  });

  @override
  ConsumerState<SharedContentScreen> createState() => _SharedContentScreenState();
}

class _SharedContentScreenState extends ConsumerState<SharedContentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploadingIcon = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showThemeSelector(BuildContext context, WidgetRef ref, {required bool isGroup, required bool isAdmin}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final currentTheme = ref.watch(chatThemeProvider(widget.roomId));

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF262626))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(AthIcons.swatch, color: AppTheme.primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Chat Theme',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isGroup
                        ? (isAdmin ? 'Change theme for all group members' : 'Group theme (Set by Admin)')
                        : 'Pick a theme for your conversation',
                    style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: kAvailableChatThemes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final theme = kAvailableChatThemes[index];
                      final isSelected = theme.id == currentTheme.id;

                      return InkWell(
                        onTap: () async {
                          if (isGroup && !isAdmin) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Only the group admin can change the group chat theme.'),
                                backgroundColor: Colors.orangeAccent,
                              ),
                            );
                            return;
                          }

                          HapticFeedback.selectionClick();
                          if (isGroup) {
                            await ref.read(chatRepositoryProvider).updateGroupTheme(widget.roomId, theme.id);
                          }
                          await ref.read(chatThemeProvider(widget.roomId).notifier).setTheme(theme.id);
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Chat theme updated to ${theme.name}!'),
                                backgroundColor: theme.accentColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E1E1E) : const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? theme.accentColor : const Color(0xFF262626),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: theme.bubbleGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.bubbleGradient.first.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(theme.emoji, style: const TextStyle(fontSize: 16)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      theme.name,
                                      style: TextStyle(
                                        color: isSelected ? theme.accentColor : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ambient gradient & accents',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(AthIcons.checkCircleSolid, color: theme.accentColor, size: 22),
                            ],
                          ),
                        ),
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

  void _showRenameGroupDialog(BuildContext context, ChatRoom room) {
    final nameCtrl = TextEditingController(text: room.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262626)),
        ),
        title: const Text('Rename Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Group Name',
            labelStyle: TextStyle(color: AppTheme.primaryColor),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(chatRepositoryProvider).updateGroupDetails(
                  widget.roomId,
                  name: newName,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group name updated!'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showGroupIconPicker(BuildContext context, ChatRoom room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF262626)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Group Icon',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AthIcons.camera, color: AppTheme.primaryColor, size: 20),
                ),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadGroupIcon(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AthIcons.photo, color: AppTheme.primaryColor, size: 20),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadGroupIcon(ImageSource.gallery);
                },
              ),
              if (room.iconUrl?.isNotEmpty == true)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(AthIcons.trash, color: Colors.redAccent, size: 20),
                  ),
                  title: const Text('Remove Group Icon', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeGroupIcon();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadGroupIcon(ImageSource source) async {
    if (_isUploadingIcon) return;
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      if (mounted) {
        setState(() {
          _isUploadingIcon = true;
        });
      }

      final bytes = kIsWeb ? await image.readAsBytes() : null;
      final filePath = kIsWeb ? null : image.path;
      final fileName = 'group_${widget.roomId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final idempotencyKey = const Uuid().v4();

      final queue = ref.read(uploadQueueProvider.notifier);
      final taskId = await queue.addTask(
        bytes: bytes,
        filePath: filePath,
        fileName: fileName,
        ownerType: 'chat',
        idempotencyKey: idempotencyKey,
      );

      UploadTask? completedTask;
      await for (final tasks in ref.read(uploadQueueProvider.notifier).stream) {
        final t = tasks.where((task) => task.id == taskId).firstOrNull;
        if (t == null) break;
        if (t.status == UploadStatus.completed) {
          completedTask = t;
          break;
        }
        if (t.status == UploadStatus.failed || t.status == UploadStatus.cancelled) {
          throw Exception(t.errorMessage ?? 'Upload failed');
        }
      }

      if (completedTask == null || completedTask.mediaId == null) {
        throw Exception('Group photo task failed to return media ID');
      }

      final doc = await FirebaseFirestore.instance.collection('media').doc(completedTask.mediaId).get();
      final urls = doc.data()?['urls'] as Map?;
      final downloadUrl = urls?['original'] as String? ?? urls?['thumbnail'] as String?;
      if (downloadUrl == null) {
        throw Exception('Group icon URL is missing.');
      }

      await ref.read(chatRepositoryProvider).updateGroupDetails(
        widget.roomId,
        iconUrl: downloadUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group icon updated successfully!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e, fallback: 'Failed to update group icon. Please try again.')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingIcon = false;
        });
      }
    }
  }

  Future<void> _removeGroupIcon() async {
    try {
      await ref.read(chatRepositoryProvider).updateGroupDetails(
        widget.roomId,
        iconUrl: '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group icon removed'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e, fallback: 'Failed to remove icon. Please try again.'))),
        );
      }
    }
  }

  void _showAddMembersModal(BuildContext context, ChatRoom room) {
    final searchCtrl = TextEditingController();
    final selectedToAdd = <String>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF262626)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final profilesAsync = ref.watch(profileListProvider);
            final allProfiles = profilesAsync.maybeWhen(data: (l) => l, orElse: () => <ProfileModel>[]);
            final nonMembers = allProfiles
                .where((p) => !room.participantIds.contains(p.id))
                .where((p) {
                  final query = searchCtrl.text.toLowerCase().trim();
                  if (query.isEmpty) return true;
                  return p.name.toLowerCase().contains(query) || p.username.toLowerCase().contains(query);
                })
                .toList();

            return SafeArea(
              top: false,
              bottom: true,
              child: Container(
                padding: EdgeInsets.only(
                  top: 16,
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Members',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(AthIcons.xMark, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF262626)),
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search athletes...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                          prefixIcon: Icon(AthIcons.search, color: Colors.white38, size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: nonMembers.isEmpty
                          ? const Center(
                              child: Text('No new athletes to add', style: TextStyle(color: Colors.white38, fontSize: 13)),
                            )
                          : ListView.builder(
                              itemCount: nonMembers.length,
                              itemBuilder: (ctx, index) {
                                final p = nonMembers[index];
                                final isSelected = selectedToAdd.contains(p.id);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: (p.avatarUrl.isNotEmpty && (p.avatarUrl.startsWith('http://') || p.avatarUrl.startsWith('https://')))
                                        ? NetworkImage(p.avatarUrl)
                                        : null,
                                    backgroundColor: Colors.white10,
                                    child: (p.avatarUrl.isEmpty || (!p.avatarUrl.startsWith('http://') && !p.avatarUrl.startsWith('https://')))
                                        ? const Icon(AthIcons.userSolid, size: 18, color: Colors.white54)
                                        : null,
                                  ),
                                  title: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  subtitle: Text('${p.role} • ${p.sport}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    activeColor: AppTheme.primaryColor,
                                    checkColor: Colors.black,
                                    onChanged: (val) {
                                      setSheetState(() {
                                        if (val == true) {
                                          selectedToAdd.add(p.id);
                                        } else {
                                          selectedToAdd.remove(p.id);
                                        }
                                      });
                                    },
                                  ),
                                  onTap: () {
                                    setSheetState(() {
                                      if (isSelected) {
                                        selectedToAdd.remove(p.id);
                                      } else {
                                        selectedToAdd.add(p.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedToAdd.isNotEmpty ? AppTheme.primaryColor : Colors.white12,
                          foregroundColor: selectedToAdd.isNotEmpty ? Colors.black : Colors.white38,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: selectedToAdd.isNotEmpty
                            ? () async {
                                await ref.read(chatRepositoryProvider).addGroupMembers(widget.roomId, selectedToAdd.toList());
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added ${selectedToAdd.length} member(s) to group.'),
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: Text('Add (${selectedToAdd.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleLeaveGroup(BuildContext context, String myId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262626)),
        ),
        title: const Text('Leave Group?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to leave this group? You will no longer receive messages from this conversation.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(chatRepositoryProvider).leaveGroup(widget.roomId, myId);
      if (context.mounted) {
        context.go('/chat');
      }
    }
  }

  void _handleBlockUser(BuildContext context, String receiverId, String userName, bool isBlocked) async {
    final actions = ref.read(settingsActionsProvider);
    if (isBlocked) {
      await actions.unblockUser(receiverId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName has been unblocked.'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF121212),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF262626)),
          ),
          title: Text('Block $userName?', style: const TextStyle(color: Colors.white)),
          content: Text(
            'They will not be able to message you or view your profile and posts on Atheleos.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await actions.blockUser(receiverId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName has been blocked.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(loggedInUserIdProvider);
    final roomDetailsAsync = ref.watch(chatRoomDetailsProvider(widget.roomId));
    final roomDetails = roomDetailsAsync.valueOrNull;

    final isGroup = widget.roomId.startsWith('group_') || (roomDetails?.isGroup ?? false);
    final isAdmin = isGroup && (roomDetails?.adminId == myId || (roomDetails?.adminIds.contains(myId) ?? false));

    final effectiveReceiverId = widget.receiverId.isNotEmpty
        ? widget.receiverId
        : (roomDetails?.participantIds.firstWhere((id) => id != myId, orElse: () => '') ?? '');

    final receiverProfileAsync = ref.watch(userProvider(effectiveReceiverId));
    final allProfiles = ref.watch(profileListProvider).valueOrNull ?? [];
    ProfileModel? fallbackProfile;
    try {
      fallbackProfile = allProfiles.firstWhere((p) => p.id == effectiveReceiverId || p.username == effectiveReceiverId);
    } catch (_) {}
    final effectiveProfile = receiverProfileAsync.valueOrNull ?? fallbackProfile;

    final blockedList = ref.watch(blockedUsersStreamProvider).valueOrNull ?? [];
    final isBlocked = !isGroup && effectiveReceiverId.isNotEmpty && blockedList.contains(effectiveReceiverId);

    // Watch all messages in room
    final messages = ref.watch(roomChatProvider(widget.roomId));

    // Shared content filters (POSTS & REELS + PROFILES)
    final postMessages = messages.where((m) =>
        (m.type == 'shared_post' && m.referencedPostId != null && m.referencedPostId!.isNotEmpty) ||
        (m.type == 'shared_reel' && m.referencedReelId != null && m.referencedReelId!.isNotEmpty)
    ).toList();

    final profileMessages = messages.where((m) =>
        m.type == 'shared_profile' && m.referencedUserId != null && m.referencedUserId!.isNotEmpty
    ).toList();

    final currentTheme = ref.watch(chatThemeProvider(widget.roomId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AthIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isGroup ? 'Group Details' : 'Details',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Top Center Profile / Group Header
                if (isGroup) ...[
                  GestureDetector(
                    onTap: isAdmin && roomDetails != null && !_isUploadingIcon
                        ? () => _showGroupIconPicker(context, roomDetails)
                        : null,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundImage: (roomDetails?.iconUrl?.isNotEmpty == true)
                              ? CachedNetworkImageProvider(roomDetails!.iconUrl!)
                              : null,
                          backgroundColor: currentTheme.accentColor.withValues(alpha: 0.15),
                          child: (roomDetails?.iconUrl == null || roomDetails!.iconUrl!.isEmpty)
                              ? Icon(AthIcons.userGroup, size: 46, color: currentTheme.accentColor)
                              : null,
                        ),
                        if (_isUploadingIcon)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (isAdmin && !_isUploadingIcon)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: currentTheme.accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(AthIcons.camera, size: 14, color: Colors.black),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          roomDetails?.name?.isNotEmpty == true ? roomDetails!.name! : 'Group Chat',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin && roomDetails != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _showRenameGroupDialog(context, roomDetails),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(AthIcons.pencilSquare, color: AppTheme.primaryColor, size: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${roomDetails?.participantIds.length ?? 0} members • ${isAdmin ? 'You are Admin' : 'Group Chat'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 20),

                  // 3 Action Buttons for Group
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: AthIcons.swatch,
                          label: 'Theme',
                          color: currentTheme.accentColor,
                          onTap: () => _showThemeSelector(context, ref, isGroup: true, isAdmin: isAdmin),
                        ),
                        if (roomDetails != null)
                          _buildActionButton(
                            icon: AthIcons.userPlus,
                            label: 'Add',
                            color: Colors.white,
                            onTap: () => _showAddMembersModal(context, roomDetails),
                          ),
                        _buildActionButton(
                          icon: AthIcons.arrowRightOnRectangle,
                          label: 'Leave',
                          color: Colors.redAccent,
                          onTap: () => _handleLeaveGroup(context, myId),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Group Members Section (with Admin Remove Support)
                  if (roomDetails != null)
                    _buildGroupMembersSection(context, ref, roomDetails, myId, isAdmin),
                ] else ...[
                  // 1-to-1 Profile Header
                  Builder(
                    builder: (context) {
                      final profile = effectiveProfile;
                      final name = (profile?.name.isNotEmpty == true)
                          ? profile!.name
                          : (profile?.username.isNotEmpty == true ? '@${profile!.username}' : 'Athlete');
                      final username = profile?.username.isNotEmpty == true ? '@${profile!.username}' : '';
                      final avatarUrl = profile?.avatarUrl ?? '';
                      final role = (profile?.role.isNotEmpty == true) ? profile!.role : 'Athlete';
                      final sport = (profile?.sport.isNotEmpty == true) ? profile!.sport : 'Sports';

                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundImage: (avatarUrl.isNotEmpty && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
                                ? NetworkImage(avatarUrl)
                                : null,
                            onBackgroundImageError: (_, __) {},
                            backgroundColor: const Color(0xFF141414),
                            child: (avatarUrl.isEmpty || (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')))
                                ? const Icon(AthIcons.userSolid, size: 46, color: Colors.white54)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (username.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              username,
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF262626)),
                            ),
                            child: Text(
                              '$role • $sport',
                              style: TextStyle(
                                color: currentTheme.accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 3 Action Buttons for 1-to-1
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton(
                                  icon: AthIcons.user,
                                  label: 'Profile',
                                  color: Colors.white,
                                  onTap: () {
                                    if (profile != null) {
                                      context.push('/profile/${profile.id}');
                                    }
                                  },
                                ),
                                _buildActionButton(
                                  icon: AthIcons.swatch,
                                  label: 'Theme',
                                  color: currentTheme.accentColor,
                                  onTap: () => _showThemeSelector(context, ref, isGroup: false, isAdmin: true),
                                ),
                                _buildActionButton(
                                  icon: isBlocked ? AthIcons.lockOpen : AthIcons.noSymbol,
                                  label: isBlocked ? 'Unblock' : 'Block',
                                  color: isBlocked ? AppTheme.primaryColor : Colors.redAccent,
                                  onTap: () => _handleBlockUser(context, effectiveReceiverId, name, isBlocked),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(color: Colors.white10, height: 1),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: currentTheme.accentColor,
                indicatorWeight: 3,
                labelColor: currentTheme.accentColor,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'POSTS & REELS (${postMessages.length})'),
                  Tab(text: 'PROFILES (${profileMessages.length})'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMergedPostsTab(postMessages),
            _buildProfilesTab(profileMessages),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMembersSection(BuildContext context, WidgetRef ref, ChatRoom room, String myId, bool isCurrentUserAdmin) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Members (${room.participantIds.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  isCurrentUserAdmin ? 'Admin controls enabled' : 'Group members',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: room.participantIds.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final memberId = room.participantIds[index];
              final isMemberAdmin = memberId == room.adminId || room.adminIds.contains(memberId);
              final isMe = memberId == myId;

              return _GroupMemberTile(
                roomId: widget.roomId,
                memberId: memberId,
                isAdmin: isMemberAdmin,
                isMe: isMe,
                canRemove: isCurrentUserAdmin && !isMe,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergedPostsTab(List<ChatMessage> postMsgs) {
    if (postMsgs.isEmpty) {
      return const _EmptyTabPlaceholder(
        icon: AthIcons.squares2X2,
        title: 'No Shared Posts or Reels',
        subtitle: 'Photos, videos, and clips shared in this chat will appear here.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: postMsgs.length,
      itemBuilder: (context, index) {
        final msg = postMsgs[index];
        final isClip = msg.type == 'shared_reel' || (msg.referencedReelId != null && msg.referencedReelId!.isNotEmpty);
        final targetId = isClip ? (msg.referencedReelId ?? '') : (msg.referencedPostId ?? '');

        return _SharedContentGridTile(
          targetId: targetId,
          isClip: isClip,
        );
      },
    );
  }

  Widget _buildProfilesTab(List<ChatMessage> profileMsgs) {
    if (profileMsgs.isEmpty) {
      return const _EmptyTabPlaceholder(
        icon: AthIcons.user,
        title: 'No Shared Profiles',
        subtitle: 'Profiles shared in this chat will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: profileMsgs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final msg = profileMsgs[index];
        final userId = msg.referencedUserId!;

        return _SharedProfileListTile(userId: userId);
      },
    );
  }
}

class _GroupMemberTile extends ConsumerWidget {
  final String roomId;
  final String memberId;
  final bool isAdmin;
  final bool isMe;
  final bool canRemove;

  const _GroupMemberTile({
    required this.roomId,
    required this.memberId,
    required this.isAdmin,
    required this.isMe,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProvider(memberId));

    return profileAsync.maybeWhen(
      data: (profile) {
        final name = isMe ? 'You' : (profile?.name.isNotEmpty == true ? profile!.name : 'Athlete');
        final username = profile?.username.isNotEmpty == true ? '@${profile!.username}' : '';
        final avatarUrl = profile?.avatarUrl ?? '';
        final role = profile?.role ?? 'Athlete';

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundImage: (avatarUrl.isNotEmpty && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
                ? NetworkImage(avatarUrl)
                : null,
            backgroundColor: Colors.white12,
            child: (avatarUrl.isEmpty || (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')))
                ? const Icon(AthIcons.userSolid, size: 18, color: Colors.white54)
                : null,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            username.isNotEmpty ? '$username • $role' : role,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canRemove)
                IconButton(
                  icon: const Icon(AthIcons.userMinus, color: Colors.redAccent, size: 18),
                  tooltip: 'Remove from group',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF121212),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF262626)),
                        ),
                        title: Text('Remove $name?', style: const TextStyle(color: Colors.white)),
                        content: Text(
                          'Are you sure you want to remove $name from this group?',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(chatRepositoryProvider).leaveGroup(roomId, memberId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name removed from group.'),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                      }
                    }
                  },
                ),
              const Icon(AthIcons.chevronRight, color: Colors.white38, size: 18),
            ],
          ),
          onTap: () {
            if (!isMe) {
              context.push('/profile/$memberId');
            }
          },
        );
      },
      orElse: () => ListTile(
        dense: true,
        leading: const CircleAvatar(radius: 18, backgroundColor: Colors.white10),
        title: const Text('Loading...', style: TextStyle(color: Colors.white54, fontSize: 13)),
      ),
    );
  }
}

class _SharedContentGridTile extends ConsumerWidget {
  final String targetId;
  final bool isClip;

  const _SharedContentGridTile({
    required this.targetId,
    required this.isClip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(sharedPostDetailsProvider(targetId));

    return postAsync.when(
      loading: () => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryColor),
          ),
        ),
      ),
      error: (_, __) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: const Icon(AthIcons.photo, color: Colors.white24),
      ),
      data: (post) {
        if (post == null) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: const Center(
              child: Icon(AthIcons.informationCircle, color: Colors.white24, size: 20),
            ),
          );
        }

        final hasMedia = post.media.isNotEmpty;
        final mediaUrl = hasMedia ? (isClip ? (post.media.first.thumbnailUrl ?? post.media.first.mediaUrl) : post.media.first.mediaUrl) : '';

        return InkWell(
          onTap: () {
            if (isClip) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReelsViewerScreen(
                    clips: [post],
                    initialIndex: 0,
                  ),
                ),
              );
            } else {
              context.push('/post/${post.id}');
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: mediaUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF141414),
                          child: Icon(isClip ? AthIcons.film : AthIcons.photo, color: Colors.white30, size: 28),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF141414),
                        child: Icon(isClip ? AthIcons.film : AthIcons.photo, color: Colors.white30, size: 28),
                      ),
              ),
              if (isClip) ...[
                const Center(
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 16,
                    child: Icon(AthIcons.play, color: Colors.white, size: 22),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AthIcons.film, color: AppTheme.primaryColor, size: 10),
                        SizedBox(width: 3),
                        Text('Clip', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SharedProfileListTile extends ConsumerWidget {
  final String userId;

  const _SharedProfileListTile({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProvider(userId));

    return profileAsync.maybeWhen(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        final name = profile.name.isNotEmpty ? profile.name : 'Athlete';
        final username = profile.username.isNotEmpty ? '@${profile.username}' : '';
        final avatarUrl = profile.avatarUrl;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: (avatarUrl.isNotEmpty && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
                    ? NetworkImage(avatarUrl)
                    : null,
                onBackgroundImageError: (_, __) {},
                backgroundColor: Colors.white10,
                child: (avatarUrl.isEmpty || (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')))
                    ? const Icon(AthIcons.userSolid, size: 22, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      username.isNotEmpty ? '$username • ${profile.role}' : profile.role,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => context.push('/profile/${profile.id}'),
                child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _EmptyTabPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyTabPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.black,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
