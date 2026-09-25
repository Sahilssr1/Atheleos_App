import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atheleos/features/search/presentation/screens/search_screen.dart';
import 'package:atheleos/features/clips/presentation/controllers/clips_controller.dart';
import 'package:atheleos/features/clips/domain/repositories/clip_repository.dart';
import 'package:atheleos/features/feed/domain/models/post_model.dart';
import 'package:atheleos/features/profile/presentation/controllers/profile_controller.dart';

void main() {
  testWidgets('pumps SearchScreen with clips', (tester) async {
    final clip = PostModel(
      id: 'clip_1',
      type: 'clip',
      userId: 'user_1',
      userName: 'Test User',
      userAvatar: '',
      sport: 'Basketball',
      position: 'Guard',
      verified: false,
      content: 'A cool clip',
      media: [MediaItem(mediaUrl: 'https://example.com/video.mp4', mediaType: 'video')],
      category: PostCategory.general,
      likes: 10,
      commentsCount: 2,
      shares: 1,
      bookmarks: 0,
      views: 100,
      hasLiked: false,
      hasBookmarked: false,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loggedInUserIdProvider.overrideWith((ref) => 'user_1'),
          clipsProvider.overrideWith((ref) => ClipsNotifier(
            FakeClipRepository([clip]),
            'user_1',
            'All',
            {},
            {},
            ref,
          )),
        ],
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}

class FakeClipRepository implements ClipRepository {
  final List<PostModel> _clips;
  FakeClipRepository([this._clips = const []]);

  @override
  Stream<List<PostModel>> watchClips({String? currentUserId}) => Stream.value(_clips);

  @override
  Stream<List<PostModel>> watchClipsFiltered({required String sport, String? currentUserId}) => Stream.value(_clips);

  @override
  Future<List<PostModel>> getClipsPaginated({
    required String sport,
    int limit = 8,
    String? lastClipId,
    String? currentUserId,
  }) async {
    return _clips;
  }

  @override
  Future<void> createClip(PostModel clip) async {}

  @override
  Future<void> deleteClip(String clipId) async {}

  @override
  Future<PostModel?> getClipById(String clipId) async {
    return null;
  }
}
