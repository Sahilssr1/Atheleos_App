import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:atheleos/features/chat/domain/models/media_attachment.dart';
import 'package:atheleos/features/chat/data/services/media_resolver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaResolverService MIME & Magic Byte Detection', () {
    final resolver = MediaResolverService.instance;

    test('Identifies GIF87a magic bytes correctly', () {
      final gif87aBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x37, 0x61, 0x00, 0x00]);
      final mime = resolver.detectMimeType(gif87aBytes);
      expect(mime, equals('image/gif'));
    });

    test('Identifies GIF89a magic bytes correctly', () {
      final gif89aBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x00, 0x00]);
      final mime = resolver.detectMimeType(gif89aBytes);
      expect(mime, equals('image/gif'));
    });

    test('Identifies JPEG magic bytes correctly', () {
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final mime = resolver.detectMimeType(jpegBytes);
      expect(mime, equals('image/jpeg'));
    });

    test('Identifies PNG magic bytes correctly', () {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final mime = resolver.detectMimeType(pngBytes);
      expect(mime, equals('image/png'));
    });

    test('Identifies WebP magic bytes correctly', () {
      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x24, 0x00, 0x00, 0x00,
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      final mime = resolver.detectMimeType(webpBytes);
      expect(mime, equals('image/webp'));
    });

    test('Resolves raw GIF bytes into NormalizedAttachment without loss of animation flag', () async {
      final gifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x10, 0x20]);
      final att = await resolver.resolveBytes(
        bytes: gifBytes,
        source: AttachmentSource.keyboard,
        suggestedFileName: 'sample.gif',
      );

      expect(att.type, equals(MediaAttachmentType.gif));
      expect(att.mimeType, equals('image/gif'));
      expect(att.isAnimated, isTrue);
      expect(att.source, equals(AttachmentSource.keyboard));
    });

    test('Resolves Remote Tenor/Giphy GIF URL correctly', () {
      const url = 'https://media.tenor.com/abc123xyz/sports_win.gif';
      final att = resolver.resolveRemoteUrl(
        url: url,
        source: AttachmentSource.gifProvider,
        width: 400,
        height: 300,
      );

      expect(att.type, equals(MediaAttachmentType.gif));
      expect(att.remoteUrl, equals(url));
      expect(att.isAnimated, isTrue);
      expect(att.uploadState, equals(AttachmentUploadState.readyToSend));
    });
  });
}
