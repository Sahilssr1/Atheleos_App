import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Screens
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
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
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/verification_dashboard_screen.dart';
import '../../features/profile/presentation/screens/portfolio_analytics_screen.dart';
import '../../features/profile/presentation/screens/devices_dashboard_screen.dart';
import '../../features/profile/presentation/screens/account_settings_screens.dart';
import '../../features/profile/presentation/screens/safety_support_screens.dart';

final authStateProvider = StateProvider<bool>((ref) => false);

final appRouterProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (!isAuthenticated) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn) {
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
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
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
                routes: [
                  GoRoute(
                    path: ':userId',
                    builder: (context, state) {
                      final userId = state.pathParameters['userId'];
                      return ProfileScreen(userId: userId);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Stack navigation routes pushed over the bottom tab view
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
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
              final receiverId =
                  state.uri.queryParameters['receiverId'] ?? 'coach_1';
              return ChatScreen(receiverId: receiverId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'verification',
            builder: (context, state) => const VerificationDashboardScreen(),
          ),
          GoRoute(
            path: 'portfolio',
            builder: (context, state) => const PortfolioAnalyticsScreen(),
          ),
          GoRoute(
            path: 'devices',
            builder: (context, state) => const DevicesDashboardScreen(),
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
            path: 'phone',
            builder: (context, state) => const PhoneVerificationScreen(),
          ),
          GoRoute(
            path: 'password',
            builder: (context, state) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: 'alternate-email',
            builder: (context, state) => const AlternateEmailScreen(),
          ),
          GoRoute(
            path: 'recovery-phone',
            builder: (context, state) =>
                const PhoneVerificationScreen(recoveryPhone: true),
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
          GoRoute(
            path: 'two-factor',
            builder: (context, state) => const SettingsDocumentScreen(
              title: 'TWO-FACTOR AUTHENTICATION',
              sections: [
                (
                  'Coming Soon',
                  'Two-factor authentication is being prepared for a future release.'
                )
              ],
            ),
          ),
          GoRoute(
            path: 'connected/:service',
            builder: (context, state) => SettingsDocumentScreen(
              title: (state.pathParameters['service'] ?? 'CONNECTED SERVICE')
                  .replaceAll('-', ' ')
                  .toUpperCase(),
              sections: const [
                (
                  'Coming Soon',
                  'This connected service integration is being prepared for a future release.'
                )
              ],
            ),
          ),
        ],
      ),
    ],
  );
});

// A production-grade shell widget leveraging StatefulNavigationShell
class MainNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index == 4) {
            // Tapping the Profile tab resets the profile view to the logged-in user
            ref.read(currentProfileIdProvider.notifier).state =
                ref.read(loggedInUserIdProvider);
            context.go('/profile');
            VisibilityDetectorController.instance.notifyNow();
            return;
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
          VisibilityDetectorController.instance.notifyNow();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Clips',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
