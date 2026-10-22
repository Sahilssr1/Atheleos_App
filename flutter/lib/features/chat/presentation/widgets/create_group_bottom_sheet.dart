import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../controllers/chat_controller.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

class CreateGroupBottomSheet extends ConsumerStatefulWidget {
  final List<ProfileModel> availableProfiles;
  final String myId;

  const CreateGroupBottomSheet({
    super.key,
    required this.availableProfiles,
    required this.myId,
  });

  static Future<void> show(BuildContext context, List<ProfileModel> profiles, String myId) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFF262626)),
      ),
      isScrollControlled: true,
      builder: (context) => CreateGroupBottomSheet(
        availableProfiles: profiles,
        myId: myId,
      ),
    );
  }

  @override
  ConsumerState<CreateGroupBottomSheet> createState() => _CreateGroupBottomSheetState();
}

class _CreateGroupBottomSheetState extends ConsumerState<CreateGroupBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedMemberIds = {};
  bool _isCreating = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup(List<ProfileModel> selectedProfiles) async {
    if (_selectedMemberIds.isEmpty || _isCreating) return;

    // Auto-generate name if empty (like Instagram & WhatsApp)
    String groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      final names = selectedProfiles.map((p) => p.name.split(' ').first).toList();
      if (names.length <= 2) {
        groupName = names.join(' & ');
      } else {
        groupName = '${names.take(2).join(', ')} & ${names.length - 2} others';
      }
    }

    setState(() => _isCreating = true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final roomId = await repo.createGroupRoom(
        name: groupName,
        adminId: widget.myId,
        memberIds: _selectedMemberIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context);
        context.push('/chat/room?roomId=$roomId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e, fallback: 'Failed to create group. Please try again.')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidateProfiles = widget.availableProfiles
        .where((p) => p.id != widget.myId)
        .where((p) {
          if (_searchQuery.isEmpty) return true;
          return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.sport.toLowerCase().contains(_searchQuery.toLowerCase());
        })
        .toList();

    final selectedProfiles = widget.availableProfiles
        .where((p) => _selectedMemberIds.contains(p.id))
        .toList();

    final hasSelection = _selectedMemberIds.isNotEmpty;

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
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Group Chat',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(AthIcons.xMark, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Group Name Input
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Enter group name (optional)...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: Icon(AthIcons.userGroup, color: AppTheme.primaryColor),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Selected Members Chips Bar
            if (selectedProfiles.isNotEmpty) ...[
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedProfiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final profile = selectedProfiles[index];
                    return Stack(
                      children: [
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage: (profile.avatarUrl.isNotEmpty &&
                                      (profile.avatarUrl.startsWith('http://') || profile.avatarUrl.startsWith('https://')))
                                  ? NetworkImage(profile.avatarUrl)
                                  : null,
                              onBackgroundImageError: (_, __) {},
                              backgroundColor: Colors.white10,
                              child: (profile.avatarUrl.isEmpty ||
                                      (!profile.avatarUrl.startsWith('http://') && !profile.avatarUrl.startsWith('https://')))
                                  ? const Icon(AthIcons.userSolid, size: 20, color: Colors.white54)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 54,
                              child: Text(
                                profile.name.split(' ').first,
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMemberIds.remove(profile.id);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(AthIcons.xMark, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white10),
            ],

            // Search Members Filter
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Search followers & athletes...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: Icon(AthIcons.search, color: Colors.white38, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Members List
            Expanded(
              child: candidateProfiles.isEmpty
                  ? const Center(
                      child: Text(
                        'No athletes found',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: candidateProfiles.length,
                      itemBuilder: (context, index) {
                        final profile = candidateProfiles[index];
                        final isSelected = _selectedMemberIds.contains(profile.id);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundImage: (profile.avatarUrl.isNotEmpty &&
                                    (profile.avatarUrl.startsWith('http://') || profile.avatarUrl.startsWith('https://')))
                                ? NetworkImage(profile.avatarUrl)
                                : null,
                            onBackgroundImageError: (_, __) {},
                            backgroundColor: Colors.white10,
                            child: (profile.avatarUrl.isEmpty ||
                                    (!profile.avatarUrl.startsWith('http://') && !profile.avatarUrl.startsWith('https://')))
                                ? const Icon(AthIcons.userSolid, size: 18, color: Colors.white54)
                                : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.verified) ...[
                                const SizedBox(width: 4),
                                const Icon(AthIcons.checkBadgeSolid, color: Colors.blue, size: 13),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${profile.role} • ${profile.sport}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          trailing: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : Colors.white30,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(AthIcons.check, size: 16, color: Colors.black)
                                : null,
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedMemberIds.remove(profile.id);
                              } else {
                                _selectedMemberIds.add(profile.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            // Bottom Create Button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasSelection ? AppTheme.primaryColor : const Color(0xFF1E1E1E),
                  foregroundColor: hasSelection ? Colors.black : Colors.white38,
                  disabledBackgroundColor: const Color(0xFF1E1E1E),
                  disabledForegroundColor: Colors.white38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: (hasSelection && !_isCreating)
                    ? () => _handleCreateGroup(selectedProfiles)
                    : null,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        hasSelection
                            ? 'Create Group (${_selectedMemberIds.length})'
                            : 'Select members to create group',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: hasSelection ? Colors.black : Colors.white38,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
