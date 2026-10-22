import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../theme/app_theme.dart';

// Screens
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/upload/presentation/screens/upload_screen.dart';
import '../../features/clips/presentation/screens/clips_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/events/presentation/screens/events_screen.dart';
import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/event_details_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/shared_content_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/verification_dashboard_screen.dart';
import '../../features/profile/presentation/screens/portfolio_analytics_screen.dart';
import '../../features/profile/presentation/screens/account_settings_screens.dart';
import '../../features/profile/presentation/screens/safety_support_screens.dart';
import '../../features/profile/presentation/screens/following_list_screen.dart';
import '../../features/profile/domain/models/profile_model.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

final authStateProvider = StateProvider<bool>((ref) => false);

final appRouterProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/' || loc == '/feed') {
        return isAuthenticated ? '/home' : '/login';
      }

      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password';

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/feed',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Stateful shell routing preserving tab states
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/upload',
                builder: (context, state) => const UploadScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clips',
                builder: (context, state) => const ClipsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Stack navigation routes pushed over the bottom tab view
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/post/:postId',
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          final commentId = state.uri.queryParameters['commentId'];
          return PostDetailScreen(postId: postId, commentId: commentId);
        },
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateEventScreen(),
          ),
          GoRoute(
            path: ':eventId',
            builder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return EventDetailsScreen(eventId: eventId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
        routes: [
          GoRoute(
            path: 'room',
            builder: (context, state) {
              final receiverId = state.uri.queryParameters['receiverId'];
              final roomId = state.uri.queryParameters['roomId'];
              return ChatScreen(receiverId: receiverId, roomId: roomId);
            },
          ),
          GoRoute(
            path: 'shared',
            builder: (context, state) {
              final roomId = state.uri.queryParameters['roomId'] ?? '';
              final receiverId = state.uri.queryParameters['receiverId'] ?? '';
              return SharedContentScreen(roomId: roomId, receiverId: receiverId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(profile: state.extra as ProfileModel?),
        routes: [
          GoRoute(
            path: 'verification',
            builder: (context, state) => VerificationDashboardScreen(profile: state.extra as ProfileModel?),
          ),
          GoRoute(
            path: 'portfolio',
            builder: (context, state) => PortfolioAnalyticsScreen(profile: state.extra as ProfileModel?),
          ),
          GoRoute(
            path: 'edit-profile',
            builder: (context, state) => const EditProfileSettingsRoute(),
          ),
          GoRoute(
            path: 'username',
            builder: (context, state) => const ChangeUsernameScreen(),
          ),
          GoRoute(
            path: 'email',
            builder: (context, state) => const ChangeEmailScreen(),
          ),
          GoRoute(
            path: 'password',
            builder: (context, state) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: 'phone',
            builder: (context, state) => const PhoneVerificationScreen(),
          ),
          GoRoute(
            path: 'connected-account',
            builder: (context, state) => const ConnectedAccountScreen(),
          ),
          GoRoute(
            path: 'delete-account',
            builder: (context, state) => const DeleteAccountScreen(),
          ),
          GoRoute(
            path: 'following',
            builder: (context, state) => const FollowingListScreen(),
          ),
          GoRoute(
            path: 'blocked-users',
            builder: (context, state) => const SafetyUsersScreen.blocked(),
          ),
          GoRoute(
            path: 'muted-users',
            builder: (context, state) => const SafetyUsersScreen.muted(),
          ),
          GoRoute(
            path: 'hidden-keywords',
            builder: (context, state) => const HiddenKeywordsScreen(),
          ),
          GoRoute(
            path: 'report-history',
            builder: (context, state) => const ReportHistoryScreen(),
          ),
          GoRoute(
            path: 'report-problem',
            builder: (context, state) => const ReportProblemScreen(),
          ),
          GoRoute(
            path: 'contact-support',
            builder: (context, state) =>
                const ReportProblemScreen(supportRequest: true),
          ),
          GoRoute(
            path: 'help',
            builder: (context, state) => const HelpCenterScreen(),
          ),
          GoRoute(
            path: 'community-guidelines',
            builder: (context, state) => const SettingsDocumentScreen(
              title: 'COMMUNITY GUIDELINES',
              sections: SettingsDocumentScreen.communityGuidelines,
            ),
          ),
          GoRoute(
            path: 'verification-guidelines',
            builder: (context, state) => const SettingsDocumentScreen(
              title: 'VERIFICATION GUIDELINES',
              sections: SettingsDocumentScreen.verificationGuidelines,
            ),
          ),
          GoRoute(
            path: 'privacy-policy',
            builder: (context, state) => const SettingsDocumentScreen(
              title: 'PRIVACY POLICY',
              sections: SettingsDocumentScreen.privacyPolicy,
            ),
          ),
          GoRoute(
            path: 'terms',
            builder: (context, state) => const SettingsDocumentScreen(
              title: 'TERMS & CONDITIONS',
              sections: SettingsDocumentScreen.terms,
            ),
          ),
          GoRoute(
            path: 'release-notes',
            builder: (context, state) => const SettingsDocumentScreen(
              title: 'RELEASE NOTES',
              sections: SettingsDocumentScreen.releaseNotes,
            ),
          ),
        ],
      ),
    ],
  );
});

// A production-grade shell widget leveraging StatefulNavigationShell
class MainNavigationShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  DateTime? _lastBackPressed;

  void _handleBackPress() {
    // 1. If not on the Home tab (index 0), navigate to Home tab first
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
      VisibilityDetectorController.instance.notifyNow();
      return;
    }

    // 2. On Home tab: double-tap back within 2 seconds to exit
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(AthIcons.arrowRightOnRectangle, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                'Press back again to exit',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'EXIT',
            textColor: AppTheme.primaryColor,
            onPressed: () => SystemNavigator.pop(),
          ),
          backgroundColor: const Color(0xFF141414),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF262626)),
          ),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
    } else {
      // Pressed twice within 2 seconds -> exit app
      ScaffoldMessenger.of(context).clearSnackBars();
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        extendBody: false,
        backgroundColor: Colors.black,
        body: widget.navigationShell,
        bottomNavigationBar: _buildBottomNavBar(context),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final currentIndex = widget.navigationShell.currentIndex;

    return ColoredBox(
      color: Colors.black,
      child: Padding(
      padding: EdgeInsets.fromLTRB(8, 4, 8, bottomInset > 0 ? bottomInset : 8),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xE6000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x14FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0xCC000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            currentIndex: currentIndex,
            label: 'Home',
            icon: AthIcons.home,
            selectedIcon: AthIcons.homeFill,
          ),
          _buildNavItem(
            index: 1,
            currentIndex: currentIndex,
            label: 'Search',
            icon: AthIcons.search,
            selectedIcon: AthIcons.search,
          ),
          _buildNavItem(
            index: 2,
            currentIndex: currentIndex,
            label: 'Upload',
            icon: AthIcons.plusCircle,
            selectedIcon: AthIcons.plusCircle,
          ),
          _buildNavItem(
            index: 3,
            currentIndex: currentIndex,
            label: 'Clips',
            icon: AthIcons.playCircle,
            selectedIcon: AthIcons.playCircle,
          ),
          _buildNavItem(
            index: 4,
            currentIndex: currentIndex,
            label: 'Profile',
            icon: AthIcons.user,
            selectedIcon: AthIcons.user,
            avatarUrl: _navAvatarUrl(),
          ),
        ],
        ),
      ),
      ),
    );
  }

  String _navAvatarUrl() {
    final fromProfile =
        ref.watch(currentUserProvider).valueOrNull?.avatarUrl.trim() ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    return FirebaseAuth.instance.currentUser?.photoURL ?? '';
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    String? avatarUrl,
  }) {
    final isSelected = index == currentIndex;
    final photo = avatarUrl?.trim() ?? '';
    final hasPhoto = photo.startsWith('http');

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          if (index == 4) {
            // Tapping the Profile tab resets the profile view to the logged-in user
            ref.read(currentProfileIdProvider.notifier).state =
                ref.read(loggedInUserIdProvider);
            context.go('/profile');
            VisibilityDetectorController.instance.notifyNow();
            return;
          }
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
          VisibilityDetectorController.instance.notifyNow();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 16 : 4,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: Color(0x66E5A93B),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: hasPhoto
                  ? CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF1A1A1A),
                      backgroundImage: CachedNetworkImageProvider(
                        photo,
                        maxWidth: 72,
                        maxHeight: 72,
                      ),
                    )
                  : Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected ? Colors.black : Colors.white,
                      size: 20,
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.1,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
