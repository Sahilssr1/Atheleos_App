import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_loader.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _lastTrackedId;

  void _trackView(String activeId) {
    if (_lastTrackedId == activeId) return;
    _lastTrackedId = activeId;
    
    final loggedInId = ref.read(loggedInUserIdProvider);
    if (activeId != loggedInId) {
      ref.read(userRepositoryProvider).incrementProfileViews(activeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String activeId = widget.userId ?? ref.watch(loggedInUserIdProvider);

    // Sync activeId with currentProfileIdProvider reactively and track views
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackView(activeId);
      if (ref.read(currentProfileIdProvider) != activeId) {
        ref.read(currentProfileIdProvider.notifier).state = activeId;
      }
    });

    final activeProfileAsync = ref.watch(activeProfileProvider);

    // Dynamically update App Bar title based on the loaded profile's role
    final String appBarTitle = activeProfileAsync.when(
      data: (profile) => profile != null ? '${profile.role.toUpperCase()} PROFILE' : 'ATHLETE PROFILE',
      loading: () => 'LOADING PROFILE...',
      error: (_, __) => 'PROFILE ERROR',
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            fontSize: 15,
          ),
        ),
        actions: [
          // Settings gear — only visible on the owner's own profile
          if (activeId == ref.watch(loggedInUserIdProvider))
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      body: ProfileLoader(userId: activeId),
    );
  }
}
