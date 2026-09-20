import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:atheleos/features/notifications/domain/models/notification_model.dart';
import 'package:atheleos/features/notifications/presentation/widgets/follow_back_button.dart';
import 'package:atheleos/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:atheleos/features/profile/presentation/controllers/profile_controller.dart';
import 'package:atheleos/features/profile/presentation/controllers/settings_controller.dart';
import 'package:atheleos/features/profile/domain/models/profile_model.dart';
import 'package:atheleos/features/profile/domain/repositories/user_repository.dart';

class FakeUserRepository implements UserRepository {
  final Map<String, ProfileModel> users = {};
  final Set<String> followedUserIds = {};

  @override
  Future<ProfileModel?> getUserById(String id) async => users[id];

  @override
  Future<ProfileModel?> getCurrentUser() async => users['my_user_id'];

  @override
  Future<List<ProfileModel>> getAllUsers({int limit = 50}) async =>
      users.values.take(limit).toList();

  @override
  Future<List<ProfileModel>> getUsersByRole(String role, {int limit = 50}) async =>
      users.values.where((u) => u.role == role).take(limit).toList();

  @override
  Future<void> updateFollowState(String userId, bool isFollowing) async {
    if (isFollowing) {
      followedUserIds.add(userId);
    } else {
      followedUserIds.remove(userId);
    }
  }

  @override
  Future<void> updateUser(ProfileModel user) async {
    users[user.id] = user;
  }

  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    await updateFollowState(targetUserId, !followedUserIds.contains(targetUserId));
  }

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late FakeUserRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeUserRepository();
  });

  group('Notification Follow Back & Mutual Follow Tests', () {
    test('Follow notification has correct type, metadata and pointsToProfile', () {
      final notif = AppNotification(
        id: 'notif_follow_1',
        type: NotificationType.follow,
        senderId: 'user_real_99',
        senderName: 'Jordan Vance',
        senderAvatar: '',
        receiverId: 'my_user_id',
        title: 'New Follower',
        body: 'started following you',
        createdAt: DateTime.now(),
        read: false,
      );

      expect(notif.type, equals(NotificationType.follow));
      expect(notif.pointsToProfile, isTrue);
      expect(notif.category, equals(NotificationCategory.social));
      expect(notif.senderId, equals('user_real_99'));
      expect(notif.body, contains('started following you'));
    });

    test('Non-follow notification does not point to profile by default', () {
      final notif = AppNotification(
        id: 'notif_like_1',
        type: NotificationType.postLike,
        senderId: 'user_real_99',
        senderName: 'Jordan Vance',
        senderAvatar: '',
        receiverId: 'my_user_id',
        title: 'New Like',
        body: 'liked your post',
        createdAt: DateTime.now(),
        read: false,
      );

      expect(notif.type, equals(NotificationType.postLike));
      expect(notif.pointsToProfile, isFalse);
    });

    testWidgets('FollowBackButton renders "Follow back" when user is not followed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggedInUserIdProvider.overrideWith((ref) => 'my_user_id'),
            userRepositoryProvider.overrideWithValue(fakeRepo),
            isUserFollowingStreamProvider('target_user_456')
                .overrideWith((ref) => Stream.value(false)),
            followingUsersStreamProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FollowBackButton(
                targetUserId: 'target_user_456',
                targetUserName: 'alex_athlete',
                notificationId: 'notif_123',
                isNotificationRead: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display "Follow back"
      expect(find.text('Follow back'), findsOneWidget);
      expect(find.text('Following'), findsNothing);
    });

    testWidgets('FollowBackButton renders "Following" when user is already followed in stream',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggedInUserIdProvider.overrideWith((ref) => 'my_user_id'),
            userRepositoryProvider.overrideWithValue(fakeRepo),
            isUserFollowingStreamProvider('target_user_456')
                .overrideWith((ref) => Stream.value(true)),
            followingUsersStreamProvider
                .overrideWith((ref) => Stream.value(['target_user_456'])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FollowBackButton(
                targetUserId: 'target_user_456',
                targetUserName: 'alex_athlete',
                notificationId: 'notif_123',
                isNotificationRead: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display "Following"
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Follow back'), findsNothing);
    });

    testWidgets('FollowBackButton hides when target user is self or system',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggedInUserIdProvider.overrideWith((ref) => 'my_user_id'),
            userRepositoryProvider.overrideWithValue(fakeRepo),
            isUserFollowingStreamProvider('my_user_id')
                .overrideWith((ref) => Stream.value(false)),
            isUserFollowingStreamProvider('system')
                .overrideWith((ref) => Stream.value(false)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FollowBackButton(
                    targetUserId: 'my_user_id', // Self
                    targetUserName: 'myself',
                    notificationId: 'notif_1',
                    isNotificationRead: true,
                  ),
                  FollowBackButton(
                    targetUserId: 'system', // System
                    targetUserName: 'System',
                    notificationId: 'notif_2',
                    isNotificationRead: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Follow back'), findsNothing);
      expect(find.text('Following'), findsNothing);
    });

    testWidgets('NotificationTile integrates FollowBackButton for follow notifications',
        (WidgetTester tester) async {
      final followNotification = AppNotification(
        id: 'notif_follow_real',
        type: NotificationType.follow,
        senderId: 'actor_123',
        senderName: 'sarah_runner',
        senderAvatar: '',
        receiverId: 'my_user_id',
        title: 'New Follower',
        body: 'started following you',
        createdAt: DateTime.now(),
        read: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggedInUserIdProvider.overrideWith((ref) => 'my_user_id'),
            userRepositoryProvider.overrideWithValue(fakeRepo),
            isUserFollowingStreamProvider('actor_123')
                .overrideWith((ref) => Stream.value(false)),
            followingUsersStreamProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NotificationTile(
                notification: followNotification,
                onTap: () {},
                onAvatarTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // FollowBackButton is present with "Follow back"
      expect(find.byType(FollowBackButton), findsOneWidget);
      expect(find.text('Follow back'), findsOneWidget);
    });

    testWidgets('NotificationTile does NOT show FollowBackButton for non-follow notifications',
        (WidgetTester tester) async {
      final likeNotification = AppNotification(
        id: 'notif_like_real',
        type: NotificationType.postLike,
        senderId: 'actor_123',
        senderName: 'sarah_runner',
        senderAvatar: '',
        receiverId: 'my_user_id',
        title: 'New Like',
        body: 'liked your post',
        createdAt: DateTime.now(),
        read: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loggedInUserIdProvider.overrideWith((ref) => 'my_user_id'),
            userRepositoryProvider.overrideWithValue(fakeRepo),
            isUserFollowingStreamProvider('actor_123')
                .overrideWith((ref) => Stream.value(false)),
            followingUsersStreamProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NotificationTile(
                notification: likeNotification,
                onTap: () {},
                onAvatarTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FollowBackButton), findsNothing);
      expect(find.text('Follow back'), findsNothing);
    });
  });
}
