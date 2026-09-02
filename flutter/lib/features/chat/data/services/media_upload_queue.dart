import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../domain/models/media_attachment.dart';

typedef UploadProgressCallback = void Function(double progress);
typedef UploadSuccessCallback = void Function(String remoteUrl);
typedef UploadFailureCallback = void Function(String error);

class UploadTask {
  final String messageId;
  final NormalizedAttachment attachment;
  final UploadProgressCallback? onProgress;
  final UploadSuccessCallback onComplete;
  final UploadFailureCallback onError;
  int retryAttempts;

  UploadTask({
    required this.messageId,
    required this.attachment,
    this.onProgress,
    required this.onComplete,
    required this.onError,
    this.retryAttempts = 0,
  });
}

class MediaUploadQueue {
  static final MediaUploadQueue instance = MediaUploadQueue._();
  MediaUploadQueue._();

  final List<UploadTask> _queue = [];
  final Set<String> _activeMessageIds = {};
  static const int _maxConcurrentUploads = 3;
  static const int _maxRetries = 3;

  void enqueue({
    required String messageId,
    required NormalizedAttachment attachment,
    required MediaUploadService uploadService,
    UploadProgressCallback? onProgress,
    required UploadSuccessCallback onComplete,
    required UploadFailureCallback onError,
  }) {
    if (_activeMessageIds.contains(messageId) || _queue.any((t) => t.messageId == messageId)) {
      debugPrint('[UploadQueue] Task for message $messageId already active or queued; skipping duplicate enqueue.');
      return;
    }

    final task = UploadTask(
      messageId: messageId,
      attachment: attachment,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
    );

    _queue.add(task);
    _processNext(uploadService);
  }

  void _processNext(MediaUploadService uploadService) {
    while (_activeMessageIds.length < _maxConcurrentUploads && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _activeMessageIds.add(task.messageId);
      _executeUpload(task, uploadService);
    }
  }

  Future<void> _executeUpload(UploadTask task, MediaUploadService uploadService) async {
    final att = task.attachment;

    try {
      final idempotencyKey = 'up_${task.messageId}';
      final result = await uploadService.uploadMedia(
        bytes: att.bytes,
        filePath: att.filePath,
        fileName: att.fileName,
        ownerType: 'chat',
        idempotencyKey: idempotencyKey,
        onProgress: (progress) {
          task.onProgress?.call(progress);
        },
      );

      final mediaUrl = result['mediaUrl'] as String? ??
          result['url'] as String? ??
          result['media']?['mediaUrl'] as String?;

      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        _activeMessageIds.remove(task.messageId);
        task.onComplete(mediaUrl);
        _processNext(uploadService);
        return;
      } else {
        throw Exception('Upload service returned empty media URL');
      }
    } catch (e) {
      debugPrint('[UploadQueue] Upload failed for message ${task.messageId} (attempt ${task.retryAttempts + 1}): $e');
      if (task.retryAttempts < _maxRetries) {
        task.retryAttempts++;
        final delaySeconds = 1 << task.retryAttempts; // 2s, 4s, 8s exponential backoff
        Future.delayed(Duration(seconds: delaySeconds), () {
          _activeMessageIds.remove(task.messageId);
          _queue.insert(0, task);
          _processNext(uploadService);
        });
      } else {
        _activeMessageIds.remove(task.messageId);
        task.onError(e.toString());
        _processNext(uploadService);
      }
    }
  }

  void cancel(String messageId) {
    _queue.removeWhere((t) => t.messageId == messageId);
    _activeMessageIds.remove(messageId);
  }

  bool isUploading(String messageId) => _activeMessageIds.contains(messageId);
}
