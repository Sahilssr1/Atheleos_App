import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atheleos/core/services/cache_manager.dart';
import 'package:atheleos/features/profile/domain/models/profile_model.dart';
import 'package:atheleos/features/profile/domain/repositories/user_repository.dart';
import 'package:atheleos/features/profile/presentation/controllers/profile_controller.dart';
import 'package:atheleos/features/profile/presentation/screens/edit_profile_screen.dart';

class FakeUserRepository implements UserRepository {
  final Map<String, ProfileModel> users = {};

  @override
  Future<ProfileModel?> getUserById(String id) async => users[id];

  @override
  Future<ProfileModel?> getCurrentUser() async => users['athlete_123'];

  @override
  Future<List<ProfileModel>> getAllUsers({int limit = 50}) async =>
      users.values.take(limit).toList();

  @override
  Future<List<ProfileModel>> getUsersByRole(String role, {int limit = 50}) async =>
      users.values.where((u) => u.role == role).take(limit).toList();

  @override
  Future<void> updateFollowState(String userId, bool isFollowing) async {}

  @override
  Future<void> updateUser(ProfileModel user) async {
    users[user.id] = user;
  }

  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {}

  @override
  Future<void> incrementProfileViews(String uid) async {}

  @override
  Future<void> incrementPortfolioShares(String uid) async {}

  @override
  Future<List<ProfileModel>> searchUsers({
    required String query,
    required String sport,
    required String role,
    required String state,
    required String city,
    required bool onlyVerified,
  }) async =>
      [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late FakeUserRepository fakeRepo;
  late ProfileModel testProfile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheManager().init();

    fakeRepo = FakeUserRepository();
    testProfile = ProfileModel.fromMap({
      'id': 'athlete_123',
      'name': 'Alex Morgan',
      'username': 'alexmorgan',
      'role': 'Athlete',
      'email': 'alex@example.com',
      'bio': 'Forward for national team',
      'sport': 'Soccer',
      'primaryPosition': 'Striker',
      'city': 'Los Angeles',
      'state': 'CA',
      'country': 'USA',
      'avatarUrl': '',
      'coverUrl': '',
      'height': 170.0,
      'weight': 62.0,
      'achievements': ['Olympic Gold 2024'],
      'certifications': [],
      'statistics': [],
    });
    fakeRepo.users['athlete_123'] = testProfile;
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(fakeRepo),
        loggedInUserIdProvider.overrideWith((ref) => 'athlete_123'),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('EditProfileScreen UI & Image Buttons', () {
    testWidgets('Renders Change Profile Pic and Change Banner buttons', (tester) async {
      await tester.pumpWidget(
        createTestWidget(EditProfileScreen(profile: testProfile)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Change Profile Pic'), findsOneWidget);
      expect(find.text('Change Banner'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsWidgets);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });
  });

  group('Unsaved Changes & Exit Dialog Tests', () {
    testWidgets('Exits immediately without dialog when no changes made', (tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeRepo),
            loggedInUserIdProvider.overrideWith((ref) => 'athlete_123'),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(profile: testProfile),
                      ),
                    );
                  },
                  child: const Text('Open Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Edit Profile
      await tester.tap(find.text('Open Edit'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT ATHLETE PROFILE'), findsOneWidget);

      // Tap AppBar back arrow
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Should be back on the original screen without any dialog
      expect(find.text('Unsaved Changes'), findsNothing);
      expect(find.text('Open Edit'), findsOneWidget);
    });

    testWidgets('Shows Unsaved Changes dialog when form is dirty and user tries to exit', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeRepo),
            loggedInUserIdProvider.overrideWith((ref) => 'athlete_123'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(profile: testProfile),
                      ),
                    );
                  },
                  child: const Text('Open Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Edit Profile
      await tester.tap(find.text('Open Edit'));
      await tester.pumpAndSettle();

      // Modify bio
      final bioFinder = find.widgetWithText(TextFormField, 'Forward for national team');
      await tester.enterText(bioFinder, 'Updated bio for national team');
      await tester.pumpAndSettle();

      // Tap AppBar back arrow
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Unsaved Changes'), findsOneWidget);
      expect(find.text('You have unsaved changes. Do you want to save them before exiting?'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Save & Exit'), findsOneWidget);

      // Tap Keep Editing
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      // Dialog dismissed, still on Edit Profile screen
      expect(find.text('Unsaved Changes'), findsNothing);
      expect(find.text('EDIT ATHLETE PROFILE'), findsOneWidget);

      // Tap back again and Discard
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // Screen is popped back to root
      expect(find.text('EDIT ATHLETE PROFILE'), findsNothing);
      expect(find.text('Open Edit'), findsOneWidget);
    });

    testWidgets('Saving via right checkmark saves info and exits directly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeRepo),
            loggedInUserIdProvider.overrideWith((ref) => 'athlete_123'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(profile: testProfile),
                      ),
                    );
                  },
                  child: const Text('Open Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Edit Profile
      await tester.tap(find.text('Open Edit'));
      await tester.pumpAndSettle();

      // Edit name
      final nameFinder = find.widgetWithText(TextFormField, 'Alex Morgan');
      await tester.enterText(nameFinder, 'Alexandra Morgan');
      await tester.pumpAndSettle();

      // Tap top-right checkmark button
      await tester.tap(find.byTooltip('Save Changes'));
      await tester.pumpAndSettle();

      // Should save and exit to root screen without showing Unsaved Changes dialog
      expect(find.text('Unsaved Changes'), findsNothing);
      expect(find.text('EDIT ATHLETE PROFILE'), findsNothing);
      expect(find.text('Open Edit'), findsOneWidget);
      expect(fakeRepo.users['athlete_123']?.name, equals('Alexandra Morgan'));
    });

    testWidgets('Tapping Save & Exit in dialog saves info and exits', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeRepo),
            loggedInUserIdProvider.overrideWith((ref) => 'athlete_123'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(profile: testProfile),
                      ),
                    );
                  },
                  child: const Text('Open Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Edit'));
      await tester.pumpAndSettle();

      // Change name
      final nameFinder = find.widgetWithText(TextFormField, 'Alex Morgan');
      await tester.enterText(nameFinder, 'Alex M.');
      await tester.pumpAndSettle();

      // Tap back arrow to trigger dialog
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved Changes'), findsOneWidget);

      // Tap Save & Exit
      await tester.tap(find.text('Save & Exit'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved Changes'), findsNothing);
      expect(find.text('EDIT ATHLETE PROFILE'), findsNothing);
      expect(find.text('Open Edit'), findsOneWidget);
      expect(fakeRepo.users['athlete_123']?.name, equals('Alex M.'));
    });

    testWidgets('Tapping SAVE CHANGES bottom button saves info and exits', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeRepo),
            loggedInUserIdProvider.overrideWith((ref) => 'athlete_123'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(profile: testProfile),
                      ),
                    );
                  },
                  child: const Text('Open Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Edit'));
      await tester.pumpAndSettle();

      // Scroll to and tap bottom SAVE CHANGES button
      final saveButtonFinder = find.text('SAVE CHANGES');
      await tester.scrollUntilVisible(
        saveButtonFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('EDIT ATHLETE PROFILE'), findsNothing);
      expect(find.text('Open Edit'), findsOneWidget);
    });
  });
}
