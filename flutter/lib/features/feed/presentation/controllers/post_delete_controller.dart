import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/post_model.dart';
import '../../../clips/presentation/controllers/clips_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import 'feed_controller.dart';

/// Central controller for deleting a post/reel from everywhere at once:
/// Firestore document, Cloudinary media, and all in-memory feed states.
///
/// Reused by the Feed, Reels, Search and Profile viewers so deletion behaves
/// identically no matter where it is triggered from.
final postDeleteControllerProvider = Provider<PostDeleteController>((ref) {
  return PostDeleteController(ref);
});

class PostDeleteController {
  final Ref _ref;

  PostDeleteController(this._ref);

  /// Whether [post] belongs to the currently logged-in user.
  bool isOwner(PostModel post) {
    final loggedInId = _ref.read(loggedInUserIdProvider).trim();
    final authUid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    final myId = loggedInId.isNotEmpty ? loggedInId : authUid;
    final postUid = post.userId.trim();
    return myId.isNotEmpty && (postUid.isEmpty || myId == postUid);
  }

  /// Deletes [post] and its associated media.
  ///
  /// Throws when the caller is not the owner. Firestore streams
  /// (profile grid, user posts/reels viewers) update automatically;
  /// paginated in-memory states (feed, clips) are updated here.
  Future<void> deletePost(PostModel post) async {
    if (!isOwner(post)) {
      throw StateError('Only the owner can delete this post.');
    }

    // 1. Delete the Firestore document (source of truth) + counters FIRST so backend confirms deletion.
    await _ref.read(postRepositoryProvider).deletePost(post);

    // 2. Remove from in-memory states so feed and clips update cleanly.
    if (_ref.exists(feedPostsProvider)) {
      try {
        _ref.read(feedPostsProvider.notifier).removePost(post.id);
      } catch (_) {}
    }
    if (_ref.exists(clipsProvider)) {
      try {
        _ref.read(clipsProvider.notifier).removePost(post.id);
      } catch (_) {}
    }

    // 3. Refresh profiles so postsCount and galleries stay in sync.
    try {
      _ref.read(profileListProvider.notifier).loadAllProfiles();
    } catch (_) {}
  }
}
