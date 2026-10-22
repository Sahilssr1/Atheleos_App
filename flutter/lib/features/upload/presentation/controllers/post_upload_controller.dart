import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/media_upload_service.dart';
import '../../../../core/services/mention_service.dart';
import '../../../../core/services/upload_queue_coordinator.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';

enum PostUploadStatus {
  idle,
  uploading,
  processing,
  completed,
  error,
}

class PostUploadState {
  final PostUploadStatus status;
  final double progress; // 0.0 to 1.0
  final String? caption;
  final String? sport;
  final String? category;
  final String? location;
  final String? thumbnailPath;
  final bool isVideo;
  final String? errorMessage;
  final String? postId;

  const PostUploadState({
    this.status = PostUploadStatus.idle,
    this.progress = 0.0,
    this.caption,
    this.sport,
    this.category,
    this.location,
    this.thumbnailPath,
    this.isVideo = false,
    this.errorMessage,
    this.postId,
  });

  PostUploadState copyWith({
    PostUploadStatus? status,
    double? progress,
    String? caption,
    String? sport,
    String? category,
    String? location,
    String? thumbnailPath,
    bool? isVideo,
    String? errorMessage,
    String? postId,
  }) {
    return PostUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      caption: caption ?? this.caption,
      sport: sport ?? this.sport,
      category: category ?? this.category,
      location: location ?? this.location,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isVideo: isVideo ?? this.isVideo,
      errorMessage: errorMessage ?? this.errorMessage,
      postId: postId ?? this.postId,
    );
  }
}

class PostUploadNotifier extends StateNotifier<PostUploadState> {
  final Ref _ref;
  Timer? _autoDismissTimer;
  StreamSubscription? _queueSubscription;

  PostUploadNotifier(this._ref) : super(const PostUploadState());

  void dismiss() {
    _autoDismissTimer?.cancel();
    _queueSubscription?.cancel();
    state = const PostUploadState();
  }

  Future<void> startUpload({
    required String caption,
    required PostCategory category,
    required String sport,
    String? location,
    XFile? pickedFile,
    bool isVideo = false,
  }) async {
    _autoDismissTimer?.cancel();
    _queueSubscription?.cancel();

    final postId = const Uuid().v4();
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ??
        _ref.read(loggedInUserIdProvider);
    ProfileModel? userProfile = _ref.read(currentUserProvider).valueOrNull;
    if (userProfile == null || userProfile.id != currentUid) {
      if (currentUid.isNotEmpty) {
        try {
          userProfile =
              await _ref.read(userRepositoryProvider).getUserById(currentUid);
        } catch (_) {}
      }
    }
    userProfile ??= _ref.read(activeProfileProvider).valueOrNull;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final String resolvedId = (userProfile != null && userProfile.id.isNotEmpty)
        ? userProfile.id
        : currentUid;
    final String resolvedName =
        (userProfile != null && userProfile.name.isNotEmpty)
            ? userProfile.name
            : (firebaseUser?.displayName != null &&
                    firebaseUser!.displayName!.isNotEmpty
                ? firebaseUser.displayName!
                : 'Athlete');
    final String resolvedAvatar =
        (userProfile != null && userProfile.avatarUrl.isNotEmpty)
            ? userProfile.avatarUrl
            : (firebaseUser?.photoURL ?? '');
    final String resolvedPosition =
        (userProfile != null && userProfile.primaryPosition.isNotEmpty)
            ? (userProfile.primaryPosition.split(' ').firstOrNull ?? 'Athlete')
            : 'Athlete';
    final bool resolvedVerified = userProfile?.verified ?? false;

    state = PostUploadState(
      status: PostUploadStatus.uploading,
      progress: 0.05,
      caption: caption,
      sport: sport,
      category: category.name,
      location: location,
      thumbnailPath: pickedFile?.path,
      isVideo: isVideo,
      postId: postId,
    );

    try {
      String? mediaUrl;
      String? thumbnailUrl;
      String? uploadedMediaId;
      int? actualWidth;
      int? actualHeight;
      double? actualDuration;

      if (pickedFile != null) {
        Uint8List? bytes;
        String? filePath;

        if (kIsWeb) {
          bytes = await pickedFile.readAsBytes();
        } else {
          filePath = pickedFile.path;
        }

        final idempotencyKey = const Uuid().v4();
        final queue = _ref.read(uploadQueueProvider.notifier);

        final taskId = await queue.addTask(
          bytes: bytes,
          filePath: filePath,
          fileName: pickedFile.name,
          ownerType: 'post',
          idempotencyKey: idempotencyKey,
        );

        final completer = Completer<UploadTask>();
        _queueSubscription = queue.stream.listen((tasks) {
          final matching = tasks.where((t) => t.id == taskId);
          final t = matching.isNotEmpty ? matching.first : null;
          if (t == null) return;

          if (t.status == UploadStatus.completed) {
            if (!completer.isCompleted) completer.complete(t);
          } else if (t.status == UploadStatus.failed ||
              t.status == UploadStatus.cancelled) {
            if (!completer.isCompleted) {
              completer
                  .completeError(Exception(t.errorMessage ?? 'Upload failed'));
            }
          } else {
            // Map queue progress (0 to 1) into post upload progress (0.05 to 0.75)
            final mapped = 0.05 + (t.progress * 0.70);
            state = state.copyWith(progress: mapped);
          }
        });

        final completedTask = await completer.future.timeout(
          const Duration(minutes: 3),
          onTimeout: () => throw TimeoutException(
              'Upload took too long. Please check connection.'),
        );

        if (completedTask.mediaId == null) {
          throw Exception('Upload task failed to return media ID.');
        }

        final mediaId = completedTask.mediaId!;
        uploadedMediaId = mediaId;

        state = state.copyWith(
          status: PostUploadStatus.processing,
          progress: 0.82,
        );

        // Fetch media URLs with resilient fallback
        DocumentSnapshot<Map<String, dynamic>>? docSnap;
        try {
          docSnap = await FirebaseFirestore.instance
              .collection('media')
              .doc(mediaId)
              .snapshots()
              .firstWhere((snap) {
            if (!snap.exists) return false;
            final data = snap.data();
            if (data == null) return false;
            final s = data['status'];
            final urls = data['urls'];
            return s == 'ready' ||
                s == 'completed' ||
                (urls is Map &&
                    (urls['original'] != null || urls['public'] != null));
          }).timeout(const Duration(seconds: 12));
        } catch (_) {
          try {
            final direct = await FirebaseFirestore.instance
                .collection('media')
                .doc(mediaId)
                .get();
            if (direct.exists) docSnap = direct;
          } catch (_) {}
        }

        if (docSnap != null && docSnap.exists && docSnap.data() != null) {
          final mediaData = docSnap.data()!;
          final urls = mediaData['urls'] as Map?;
          if (urls != null) {
            mediaUrl = urls['original'] as String? ??
                urls['public'] as String? ??
                urls['url'] as String?;
            thumbnailUrl =
                urls['thumbnail'] as String? ?? urls['thumb'] as String?;
          }

          if (isVideo && mediaData['videoMetadata'] != null) {
            final vMeta = mediaData['videoMetadata'] as Map<dynamic, dynamic>;
            final vWidth = (vMeta['width'] as num?)?.toInt();
            final vHeight = (vMeta['height'] as num?)?.toInt();
            if (vWidth != null &&
                vWidth > 0 &&
                vHeight != null &&
                vHeight > 0) {
              actualWidth = vWidth;
              actualHeight = vHeight;
            }
            final vDur = (vMeta['duration'] as num?)?.toDouble();
            if (vDur != null && vDur > 0) {
              actualDuration = vDur;
            }
          }
        }

        if (mediaUrl == null && isVideo) {
          throw Exception(
              'Video is still processing. Please try again in a moment.');
        }
        if (mediaUrl == null) {
          final workerUrl = _ref.read(cloudflareConfigProvider).workerUrl;
          mediaUrl = '$workerUrl/media/$mediaId.jpg';
        }

        // Measure local dimensions if not already retrieved
        if (actualWidth == null || actualHeight == null) {
          try {
            if (isVideo) {
              VideoPlayerController? tempController;
              try {
                if (kIsWeb) {
                  tempController =
                      VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
                } else {
                  tempController =
                      VideoPlayerController.file(File(pickedFile.path));
                }
                await tempController.initialize();
                final bool isRotated =
                    tempController.value.rotationCorrection == 90 ||
                        tempController.value.rotationCorrection == 270;
                actualWidth = (isRotated
                        ? tempController.value.size.height
                        : tempController.value.size.width)
                    .toInt();
                actualHeight = (isRotated
                        ? tempController.value.size.width
                        : tempController.value.size.height)
                    .toInt();
              } catch (_) {
              } finally {
                tempController?.dispose();
              }
            } else {
              final fileBytes = await pickedFile.readAsBytes();
              final codec = await ui.instantiateImageCodec(fileBytes);
              final frame = await codec.getNextFrame();
              actualWidth = frame.image.width;
              actualHeight = frame.image.height;
              frame.image.dispose();
            }
          } catch (_) {}
        }
      }

      state = state.copyWith(progress: 0.90);

      final mediaList = mediaUrl != null
          ? [
              MediaItem(
                mediaUrl: mediaUrl,
                mediaType: isVideo ? 'video' : 'image',
                thumbnailUrl: thumbnailUrl ??
                    (isVideo && mediaUrl.contains('.mp4')
                        ? mediaUrl.replaceAll('.mp4', '_thumb.jpg')
                        : (isVideo ? null : mediaUrl)),
                publicId: uploadedMediaId ?? postId,
                width: actualWidth ?? (isVideo ? 1080 : 1080),
                height: actualHeight ?? (isVideo ? 1920 : 1080),
                duration: isVideo ? (actualDuration ?? 15.0) : null,
              )
            ]
          : <MediaItem>[];

      final allProfiles = _ref.read(profileListProvider).valueOrNull ?? [];
      final mentions =
          MentionService.parseAndMapMentions(caption.trim(), allProfiles);

      final locText = location?.trim() ?? '';
      final post = PostModel(
        id: postId,
        type: 'post',
        userId: resolvedId,
        userName: resolvedName,
        userAvatar: resolvedAvatar,
        sport: sport,
        position: resolvedPosition,
        verified: resolvedVerified,
        content: caption.trim(),
        media: mediaList,
        category: category,
        location: locText.isEmpty ? null : locText,
        likes: 0,
        commentsCount: 0,
        shares: 0,
        bookmarks: 0,
        views: 0,
        hasLiked: false,
        hasBookmarked: false,
        createdAt: DateTime.now(),
        mentions: mentions,
      );

      final Map<String, dynamic> data = post.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['likeCount'] = 0;
      data['bookmarkedBy'] = <String>[];
      data['bookmarkCount'] = 0;
      if (locText.isNotEmpty) {
        data['location'] = locText;
      }

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .set(data);

      try {
        await MentionService.sendMentionNotifications(
          senderId: resolvedId,
          senderName: resolvedName,
          senderAvatar: resolvedAvatar,
          textContent: caption.trim(),
          targetType: 'post',
          targetId: postId,
          mentions: mentions,
        );
      } catch (_) {}

      if (resolvedId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(resolvedId)
              .update({'postsCount': FieldValue.increment(1)});
        } catch (_) {}
      }

      _ref.invalidate(feedPostsProvider);
      _ref.read(profileListProvider.notifier).loadAllProfiles();

      state = state.copyWith(
        status: PostUploadStatus.completed,
        progress: 1.0,
      );

      // Auto dismiss success card after 4 seconds
      _autoDismissTimer = Timer(const Duration(seconds: 4), () {
        if (state.status == PostUploadStatus.completed) {
          state = const PostUploadState();
        }
      });
    } catch (e) {
      debugPrint('PostUploadNotifier error: $e');
      state = state.copyWith(
        status: PostUploadStatus.error,
        errorMessage: UserFacingError.message(e,
            fallback: 'Upload failed. Please check connection and try again.'),
      );
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _queueSubscription?.cancel();
    super.dispose();
  }
}

final postUploadProvider =
    StateNotifierProvider<PostUploadNotifier, PostUploadState>((ref) {
  return PostUploadNotifier(ref);
});
