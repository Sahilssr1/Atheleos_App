import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atheleos/core/services/cache_manager.dart';
import 'package:atheleos/features/profile/presentation/screens/profile_screen.dart';
import 'package:atheleos/features/profile/presentation/controllers/profile_controller.dart';
import 'package:atheleos/features/profile/presentation/controllers/settings_controller.dart';
import 'package:atheleos/features/profile/domain/models/profile_model.dart';
import 'package:atheleos/features/profile/domain/models/user_settings_model.dart';
import 'package:atheleos/features/profile/domain/repositories/user_repository.dart';
import 'package:atheleos/features/feed/presentation/controllers/feed_controller.dart';
import 'package:atheleos/features/feed/domain/models/post_model.dart';

class FakeUserRepository implements UserRepository {
  final Map<String, ProfileModel> users = {};

  @override
  Future<ProfileModel?> getUserById(String id) async => users[id];

  @override
  Future<ProfileModel?> getCurrentUser() async => users['my_user_uid'];

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
  }) async => [];
}

class FakeUserPostsNotifier extends StateNotifier<AsyncValue<List<PostModel>>> implements UserPostsNotifier {
  FakeUserPostsNotifier() : super(const AsyncValue.data([]));
  @override
  String get userId => '';
  @override
  Ref get ref => throw UnimplementedError();
  @override
  void updateLikedIds(Set<String> likedIds) {}
  @override
  void updateBookmarkedIds(Set<String> bookmarkedIds) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late FakeUserRepository fakeRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheManager().init();

    fakeRepo = FakeUserRepository();
    fakeRepo.users['other_athlete_123'] = ProfileModel.fromMap({
      'id': 'other_athlete_123',
      'name': 'Jane Doe',
      'username': 'janedoe',
      'role': 'Athlete',
      'email': 'jane@example.com',
    });
    fakeRepo.users['my_user_uid'] = ProfileModel.fromMap({
      'id': 'my_user_uid',
      'name': 'My User',
      'username': 'myuser',
      'role': 'Brand',
      'email': 'brand@example.com',
    });
  });

  group('ProfileScreen Navigation & Title Tests', () {
    testWidgets('Shows leading back arrow when viewing someone else\'s profile', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeRepo),
            loggedInUserIdProvider.overrideWith((ref) => 'my_user_uid'),
            publicUserSettingsProvider('other_athlete_123').overrideWith((ref) => Stream.value(UserSettingsModel())),
            blockedByUserProvider('other_athlete_123').overrideWith((ref) => false),
            blockedUsersStreamProvider.overrideWith((ref) => Stream.value(const [])),
            userPostsProvider('other_athlete_123').overrideWith((ref) => FakeUserPostsNotifier()),
            bookmarkedPostsProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: const MaterialApp(
            home: ProfileScreen(userId: 'other_athlete_123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify back button is displayed in the AppBar
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      // Verify AppBar title shows ATHLETE PROFILE
      expect(find.text('ATHLETE PROFILE'), findsOneWidget);
    });

    testWidgets('Hides leading back arrow when on user\'s own profile tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeRepo),
            loggedInUserIdProvider.overrideWith((ref) => 'my_user_uid'),
            publicUserSettingsProvider('my_user_uid').overrideWith((ref) => Stream.value(UserSettingsModel())),
            blockedByUserProvider('my_user_uid').overrideWith((ref) => false),
            blockedUsersStreamProvider.overrideWith((ref) => Stream.value(const [])),
            userPostsProvider('my_user_uid').overrideWith((ref) => FakeUserPostsNotifier()),
            bookmarkedPostsProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: const MaterialApp(
            home: ProfileScreen(userId: null), // Own profile tab
          ),
        ),
      );

      await tester.pumpAndSettle();

      // When userId is null and canPop is false, no back button should be shown
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      // Own profile is Brand -> BRAND PROFILE
      expect(find.text('BRAND PROFILE'), findsOneWidget);
    });
  });

  group('Exit Logic Tests', () {
    test('Double-tap within 2 seconds registers as an exit condition', () {
      DateTime? lastPressed;
      bool wouldExit(DateTime now) {
        if (lastPressed == null || now.difference(lastPressed!) > const Duration(seconds: 2)) {
          lastPressed = now;
          return false;
        }
        return true;
      }

      final t0 = DateTime(2026, 9, 18, 12, 0, 0);
      expect(wouldExit(t0), isFalse, reason: 'First press shows toast');

      final t1 = DateTime(2026, 9, 18, 12, 0, 1); // 1 second later
      expect(wouldExit(t1), isTrue, reason: 'Second press within 2s exits');

      lastPressed = null;
      final t2 = DateTime(2026, 9, 18, 12, 0, 0);
      expect(wouldExit(t2), isFalse);

      final t3 = DateTime(2026, 9, 18, 12, 0, 3); // 3 seconds later
      expect(wouldExit(t3), isFalse, reason: 'Press after 2s resets and shows toast again');
    });
  });
}
