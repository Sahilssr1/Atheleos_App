import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/media_attachment.dart';

class MediaResolverService {
  static final MediaResolverService instance = MediaResolverService._();
  MediaResolverService._();

  // Magic Byte Signatures
  static const List<int> _gif87a = [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]; // GIF87a
  static const List<int> _gif89a = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]; // GIF89a
  static const List<int> _jpeg = [0xFF, 0xD8, 0xFF];
  static const List<int> _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const List<int> _webpRiff = [0x52, 0x49, 0x46, 0x46]; // RIFF
  static const List<int> _webp = [0x57, 0x45, 0x42, 0x50];     // WEBP

  /// Inspects raw header bytes to determine verified MIME type.
  String detectMimeType(Uint8List header, {String? fallbackMime, String? fileName}) {
    if (_matches(header, _gif87a) || _matches(header, _gif89a)) {
      return 'image/gif';
    }
    if (_matches(header, _jpeg)) {
      return 'image/jpeg';
    }
    if (_matches(header, _png)) {
      return 'image/png';
    }
    if (header.length >= 12 && _matches(header, _webpRiff) && _matchesSub(header, 8, _webp)) {
      return 'image/webp';
    }

    // Inspect MP4 ftyp box (bytes 4..8 == 'ftyp')
    if (header.length >= 8 &&
        header[4] == 0x66 &&
        header[5] == 0x74 &&
        header[6] == 0x79 &&
        header[7] == 0x70) {
      return 'video/mp4';
    }

    // Fallback from filename extension or caller suggestion
    if (fileName != null) {
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.gif')) return 'image/gif';
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
      if (lower.endsWith('.mp4')) return 'video/mp4';
      if (lower.endsWith('.mov')) return 'video/quicktime';
      if (lower.endsWith('.mp3')) return 'audio/mpeg';
    }

    if (fallbackMime != null && fallbackMime.isNotEmpty && fallbackMime != 'application/octet-stream') {
      return fallbackMime;
    }

    return 'application/octet-stream';
  }

  static bool _matches(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  static bool _matchesSub(Uint8List bytes, int offset, List<int> signature) {
    if (bytes.length < offset + signature.length) return false;
    for (int i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  /// Resolves raw byte buffers (e.g. from clipboard or memory cache).
  Future<NormalizedAttachment> resolveBytes({
    required Uint8List bytes,
    required AttachmentSource source,
    String? suggestedFileName,
    String? fallbackMime,
    String? messageId,
  }) async {
    final header = bytes.length > 32 ? bytes.sublist(0, 32) : bytes;
    final mime = detectMimeType(header, fallbackMime: fallbackMime, fileName: suggestedFileName);
    final ext = _extFromMime(mime);
    final fileName = suggestedFileName ?? 'media_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final type = _typeFromMime(mime);
    final isAnimated = mime == 'image/gif';

    // For larger buffers (> 256KB), write to temporary cache file to free up RAM
    String? filePath;
    Uint8List? retainedBytes = bytes;
    if (!kIsWeb && bytes.length > 256 * 1024) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        filePath = file.path;
        retainedBytes = null; // Free memory buffer
      } catch (e) {
        debugPrint('[MediaResolver] Temp cache file write failed: $e');
      }
    }

    final id = 'att_${DateTime.now().millisecondsSinceEpoch}_${bytes.length}';
    return NormalizedAttachment(
      id: id,
      type: type,
      source: source,
      filePath: filePath,
      bytes: retainedBytes,
      mimeType: mime,
      fileName: fileName,
      fileSize: bytes.length,
      isAnimated: isAnimated,
      messageId: messageId,
    );
  }

  /// Resolves local file paths deterministically by inspecting the file header.
  Future<NormalizedAttachment> resolveFile({
    required File file,
    required AttachmentSource source,
    String? fallbackMime,
    String? messageId,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('Media file does not exist', file.path);
    }

    final length = await file.length();
    // Read only the first 32 bytes to determine MIME type without loading file to RAM
    final raf = await file.open(mode: FileMode.read);
    final header = await raf.read(32);
    await raf.close();

    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'attachment';
    final mime = detectMimeType(header, fallbackMime: fallbackMime, fileName: fileName);
    final type = _typeFromMime(mime);
    final isAnimated = mime == 'image/gif';

    final id = 'att_${DateTime.now().millisecondsSinceEpoch}_$length';
    return NormalizedAttachment(
      id: id,
      type: type,
      source: source,
      filePath: file.path,
      localUri: file.uri.toString(),
      mimeType: mime,
      fileName: fileName,
      fileSize: length,
      isAnimated: isAnimated,
      messageId: messageId,
    );
  }

  /// Resolves remote URLs (e.g. Tenor/GIPHY GIF URLs).
  NormalizedAttachment resolveRemoteUrl({
    required String url,
    required AttachmentSource source,
    String? previewUrl,
    int? width,
    int? height,
    String? messageId,
  }) {
    final lower = url.toLowerCase();
    final isGif = lower.contains('.gif') || lower.contains('tenor.com') || lower.contains('giphy.com');
    final mime = isGif ? 'image/gif' : 'image/jpeg';
    final id = 'att_${DateTime.now().millisecondsSinceEpoch}_${url.hashCode.abs()}';

    return NormalizedAttachment(
      id: id,
      type: isGif ? MediaAttachmentType.gif : MediaAttachmentType.image,
      source: source,
      remoteUrl: url,
      mimeType: mime,
      fileName: 'remote_media_${id}.${_extFromMime(mime)}',
      fileSize: 0,
      width: width,
      height: height,
      isAnimated: isGif,
      uploadState: AttachmentUploadState.readyToSend,
      messageId: messageId,
    );
  }

  static MediaAttachmentType _typeFromMime(String mime) {
    if (mime == 'image/gif') return MediaAttachmentType.gif;
    if (mime.startsWith('image/')) return MediaAttachmentType.image;
    if (mime.startsWith('video/')) return MediaAttachmentType.video;
    if (mime.startsWith('audio/')) return MediaAttachmentType.audio;
    return MediaAttachmentType.file;
  }

  static String _extFromMime(String mime) {
    switch (mime) {
      case 'image/gif':
        return 'gif';
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'video/mp4':
        return 'mp4';
      default:
        return 'bin';
    }
  }
}
