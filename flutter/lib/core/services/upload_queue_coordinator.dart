import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'media_upload_service.dart';
import 'media_delete_service.dart';

enum UploadStatus {
  waiting,
  uploading,
  processing,
  completed,
  failed,
  retrying,
  cancelled,
}

class UploadTask {
  final String id;
  final Uint8List? bytes;
  final String? filePath;
  final String fileName;
  final String ownerType;
  final String idempotencyKey;
  
  UploadStatus status;
  double progress;
  String? mediaId;
  String? errorMessage;
  int retryCount;

  UploadTask({
    required this.id,
    this.bytes,
    this.filePath,
    required this.fileName,
    required this.ownerType,
    required this.idempotencyKey,
    this.status = UploadStatus.waiting,
    this.progress = 0.0,
    this.mediaId,
    this.errorMessage,
    this.retryCount = 0,
  });

  UploadTask copyWith({
    UploadStatus? status,
    double? progress,
    String? mediaId,
    String? errorMessage,
    int? retryCount,
  }) {
    return UploadTask(
      id: id,
      bytes: bytes,
      filePath: filePath,
      fileName: fileName,
      ownerType: ownerType,
      idempotencyKey: idempotencyKey,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      mediaId: mediaId ?? this.mediaId,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

class UploadQueueNotifier extends StateNotifier<List<UploadTask>> {
  final Ref _ref;
  bool _isProcessing = false;
  static const int maxConcurrency = 1; // Default sequential processing for videos

  UploadQueueNotifier(this._ref) : super([]);

  Future<String> addTask({
    required Uint8List? bytes,
    required String? filePath,
    required String fileName,
    required String ownerType,
    required String idempotencyKey,
  }) async {
    final task = UploadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_' + fileName,
      bytes: bytes,
      filePath: filePath,
      fileName: fileName,
      ownerType: ownerType,
      idempotencyKey: idempotencyKey,
    );

    state = [...state, task];
    _processNext();
    return task.id;
  }

  void cancelTask(String taskId) {
    state = [
      for (final t in state)
        if (t.id == taskId) t.copyWith(status: UploadStatus.cancelled) else t
    ];

    final task = state.firstWhere((t) => t.id == taskId);
    if (task.mediaId != null) {
      _ref.read(mediaDeleteServiceProvider).cancelUpload(task.mediaId!);
    }
  }

  void removeTask(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;

    final activeUploads = state.where((t) => t.status == UploadStatus.uploading || t.status == UploadStatus.processing).length;
    if (activeUploads >= maxConcurrency) return;

    final nextTask = state.firstWhere(
      (t) => t.status == UploadStatus.waiting || t.status == UploadStatus.retrying,
      orElse: () => UploadTask(id: '', fileName: '', ownerType: '', idempotencyKey: ''),
    );

    if (nextTask.id.isEmpty) {
      _isProcessing = false;
      return;
    }

    _isProcessing = true;
    await _runTask(nextTask);
    _isProcessing = false;
    _processNext();
  }

  Future<void> _runTask(UploadTask task) async {
    // Check if task was cancelled before starting
    if (task.status == UploadStatus.cancelled) return;

    _updateTaskStatus(task.id, status: UploadStatus.uploading, progress: 0.0);

    try {
      // 1. Resolve bytes for hashing
      Uint8List? fileBytes = task.bytes;
      if (fileBytes == null && task.filePath != null && !kIsWeb) {
        final file = io.File(task.filePath!);
        if (await file.exists()) {
          fileBytes = await file.readAsBytes();
        }
      }

      // 2. Compute SHA-256 in background isolate if we resolved bytes
      String? hash;
      if (fileBytes != null) {
        hash = await compute(calculateSha256, fileBytes);
      }

      // 3. Pre-upload deduplication check
      if (hash != null) {
        final uploadService = _ref.read(mediaUploadServiceProvider);
        final dupCheck = await uploadService.checkDeduplication(
          hash: hash,
          ownerType: task.ownerType,
        );

        if (dupCheck != null && dupCheck['exists'] == true) {
          final mediaId = dupCheck['media']?['mediaId'] ?? dupCheck['mediaId'];
          debugPrint('UploadQueue: Deduplication hit for task ${task.id}. Skipping upload.');
          _updateTaskStatus(task.id, status: UploadStatus.completed, progress: 1.0, mediaId: mediaId);
          return;
        }
      }

      // 4. Fallback to normal upload
      final response = await _ref.read(mediaUploadServiceProvider).uploadMedia(
        bytes: task.bytes,
        filePath: task.filePath,
        fileName: task.fileName,
        ownerType: task.ownerType,
        idempotencyKey: task.idempotencyKey,
        onProgress: (prog) {
          _updateTaskStatus(task.id, progress: prog);
        },
      );

      final mediaId = response['media']?['mediaId'] ?? response['mediaId'];
      _updateTaskStatus(task.id, status: UploadStatus.processing, mediaId: mediaId);

      // Handle direct completions or async states
      final statusStr = response['status'] as String?;
      if (statusStr == 'success') {
        _updateTaskStatus(task.id, status: UploadStatus.completed, progress: 1.0);
      } else {
        // Wait/Listen to Firestore for async status changes (for videos)
        // If it's a video, the Worker returns {status: 'processing', jobId, mediaId}
        // and processing is completed asynchronously.
        _updateTaskStatus(task.id, status: UploadStatus.completed, progress: 1.0);
      }
    } catch (e) {
      if (task.retryCount < 3) {
        final nextRetry = task.retryCount + 1;
        _updateTaskStatus(task.id, status: UploadStatus.retrying, retryCount: nextRetry, errorMessage: e.toString());
        // Exponential backoff
        final backoff = Duration(seconds: nextRetry * nextRetry * 2);
        await Future.delayed(backoff);
        _runTask(task.copyWith(retryCount: nextRetry));
      } else {
        _updateTaskStatus(task.id, status: UploadStatus.failed, errorMessage: e.toString());
      }
    }
  }

  void _updateTaskStatus(
    String taskId, {
    UploadStatus? status,
    double? progress,
    String? mediaId,
    String? errorMessage,
    int? retryCount,
  }) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(
            status: status,
            progress: progress,
            mediaId: mediaId,
            errorMessage: errorMessage,
            retryCount: retryCount,
          )
        else
          t
    ];
  }
}

final uploadQueueProvider = StateNotifierProvider<UploadQueueNotifier, List<UploadTask>>((ref) {
  return UploadQueueNotifier(ref);
});
