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

final authStateProvider = StateProvider<bool>((ref) => false);

final appRouterProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

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
              const Icon(Icons.exit_to_app, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                'Press back again to exit',
                style: GoogleFonts.inter(
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
        extendBody: true,
        body: widget.navigationShell,
        bottomNavigationBar: _buildFloatingBottomNavBar(context),
      ),
    );
  }

  Widget _buildFloatingBottomNavBar(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final currentIndex = widget.navigationShell.currentIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: (bottomInset > 0 ? bottomInset : 0) + 12,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF262626), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                currentIndex: currentIndex,
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
              ),
              _buildNavItem(
                index: 1,
                currentIndex: currentIndex,
                label: 'Search',
                icon: Icons.search_rounded,
                selectedIcon: Icons.search_rounded,
              ),
              _buildNavItem(
                index: 2,
                currentIndex: currentIndex,
                label: 'Upload',
                icon: Icons.add_circle_outline_rounded,
                selectedIcon: Icons.add_circle_rounded,
              ),
              _buildNavItem(
                index: 3,
                currentIndex: currentIndex,
                label: 'Clips',
                icon: Icons.play_circle_outline_rounded,
                selectedIcon: Icons.play_circle_rounded,
              ),
              _buildNavItem(
                index: 4,
                currentIndex: currentIndex,
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final isSelected = index == currentIndex;

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
              width: 58,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? Colors.black : Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
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
