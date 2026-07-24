import '../../../feed/domain/models/post_model.dart';

abstract class ClipRepository {
  Stream<List<PostModel>> watchClips({String? currentUserId});
  Stream<List<PostModel>> watchClipsFiltered({required String sport, String? currentUserId});
  Future<List<PostModel>> getClipsPaginated({required String sport, int limit = 8, String? lastClipId, String? currentUserId});
  Future<void> createClip(PostModel clip);
}
