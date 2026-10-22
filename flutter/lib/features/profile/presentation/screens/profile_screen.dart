import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_loader.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

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
    final String loggedInId = ref.watch(loggedInUserIdProvider);
    final String activeId = (widget.userId != null && widget.userId!.isNotEmpty)
        ? widget.userId!
        : loggedInId;

    final bool isViewingOther = activeId != loggedInId;

    // Sync activeId with currentProfileIdProvider reactively and track views
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackView(activeId);
      if (ref.read(currentProfileIdProvider) != activeId) {
        ref.read(currentProfileIdProvider.notifier).state = activeId;
      }
    });

    // Directly watch the active profile so it immediately reflects the viewed user's data
    final activeProfileAsync = ref.watch(universalProfileControllerProvider(activeId));

    // Dynamically update App Bar title based on the loaded profile's role
    final String appBarTitle = activeProfileAsync.when(
      data: (profile) => profile != null ? '${profile.role.toUpperCase()} PROFILE' : 'PROFILE',
      loading: () => 'PROFILE',
      error: (_, __) => 'PROFILE',
    );

    return PopScope(
      canPop: !isViewingOther || Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xE6000000),
          toolbarHeight: 52,
          shape: const Border(
            bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1),
          ),
          leading: isViewingOther || Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(AthIcons.arrowLeft, color: Colors.white, size: 20),
                  tooltip: 'Back',
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                )
              : null,
          title: Text(
            appBarTitle,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              fontSize: 14,
              color: AppTheme.primaryColor,
            ),
          ),
          actions: [
            // Settings gear — only visible on the owner's own profile
            if (!isViewingOther)
              IconButton(
                icon: const Icon(AthIcons.cog6Tooth, color: Colors.white, size: 22),
                tooltip: 'Settings',
                onPressed: () => context.push('/settings', extra: activeProfileAsync.valueOrNull),
              ),
          ],
        ),
        body: ProfileLoader(userId: activeId),
      ),
    );
  }
}
