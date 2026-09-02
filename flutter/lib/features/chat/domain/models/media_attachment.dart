import 'dart:typed_data';

enum MediaAttachmentType {
  image,
  gif,
  video,
  audio,
  file,
  sticker,
  unknown,
}

enum AttachmentSource {
  keyboard,
  gifProvider,
  gallery,
  camera,
  filePicker,
  url,
  unknown,
}

enum AttachmentUploadState {
  localPending,
  uploading,
  readyToSend,
  sent,
  failed,
}

/// Canonical internal representation of all media attachments across Atheleos.
class NormalizedAttachment {
  final String id;
  final MediaAttachmentType type;
  final AttachmentSource source;
  final String? localUri;
  final String? filePath;
  final Uint8List? bytes;
  final String? remoteUrl;
  final String mimeType;
  final String fileName;
  final int fileSize;
  final int? width;
  final int? height;
  final Duration? duration;
  final bool isAnimated;
  final AttachmentUploadState uploadState;
  final String? error;
  final double uploadProgress;
  final String? messageId;

  const NormalizedAttachment({
    required this.id,
    required this.type,
    required this.source,
    this.localUri,
    this.filePath,
    this.bytes,
    this.remoteUrl,
    required this.mimeType,
    required this.fileName,
    required this.fileSize,
    this.width,
    this.height,
    this.duration,
    this.isAnimated = false,
    this.uploadState = AttachmentUploadState.localPending,
    this.error,
    this.uploadProgress = 0.0,
    this.messageId,
  });

  bool get isGif => type == MediaAttachmentType.gif || mimeType == 'image/gif';
  bool get isImage => type == MediaAttachmentType.image || mimeType.startsWith('image/');
  bool get isVideo => type == MediaAttachmentType.video || mimeType.startsWith('video/');

  NormalizedAttachment copyWith({
    String? id,
    MediaAttachmentType? type,
    AttachmentSource? source,
    String? localUri,
    String? filePath,
    Uint8List? bytes,
    String? remoteUrl,
    String? mimeType,
    String? fileName,
    int? fileSize,
    int? width,
    int? height,
    Duration? duration,
    bool? isAnimated,
    AttachmentUploadState? uploadState,
    String? error,
    double? uploadProgress,
    String? messageId,
  }) {
    return NormalizedAttachment(
      id: id ?? this.id,
      type: type ?? this.type,
      source: source ?? this.source,
      localUri: localUri ?? this.localUri,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      mimeType: mimeType ?? this.mimeType,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      isAnimated: isAnimated ?? this.isAnimated,
      uploadState: uploadState ?? this.uploadState,
      error: error ?? this.error,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      messageId: messageId ?? this.messageId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'source': source.name,
      'localUri': localUri,
      'filePath': filePath,
      'remoteUrl': remoteUrl,
      'mimeType': mimeType,
      'fileName': fileName,
      'fileSize': fileSize,
      'width': width,
      'height': height,
      'durationMs': duration?.inMilliseconds,
      'isAnimated': isAnimated,
      'uploadState': uploadState.name,
      'error': error,
      'messageId': messageId,
    };
  }

  factory NormalizedAttachment.fromMap(Map<String, dynamic> map) {
    return NormalizedAttachment(
      id: map['id'] ?? '',
      type: MediaAttachmentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MediaAttachmentType.unknown,
      ),
      source: AttachmentSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => AttachmentSource.unknown,
      ),
      localUri: map['localUri'],
      filePath: map['filePath'],
      remoteUrl: map['remoteUrl'],
      mimeType: map['mimeType'] ?? 'application/octet-stream',
      fileName: map['fileName'] ?? 'attachment',
      fileSize: map['fileSize'] ?? 0,
      width: map['width'],
      height: map['height'],
      duration: map['durationMs'] != null ? Duration(milliseconds: map['durationMs']) : null,
      isAnimated: map['isAnimated'] == true,
      uploadState: AttachmentUploadState.values.firstWhere(
        (e) => e.name == map['uploadState'],
        orElse: () => AttachmentUploadState.localPending,
      ),
      error: map['error'],
      messageId: map['messageId'],
    );
  }
}
