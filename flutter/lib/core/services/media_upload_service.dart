import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';

class CloudflareConfig {
  final String workerUrl;

  const CloudflareConfig({
    required this.workerUrl,
  });
}

final cloudflareConfigProvider = Provider<CloudflareConfig>((ref) {
  // Configured with standard compile time variables or defaults
  const workerUrl = String.fromEnvironment(
    'CLOUDFLARE_WORKER_URL',
    defaultValue: 'https://atheleos-media-worker.atheleos-media.workers.dev',
  );
  return const CloudflareConfig(workerUrl: workerUrl);
});

class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(int bytesSent, int totalBytes) onProgress;

  MultipartRequestWithProgress(
    super.method,
    super.url, {
    required this.onProgress,
  });

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    int bytesSent = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesSent += data.length;
        onProgress(bytesSent, total);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}

abstract class MediaUploadService {
  Future<Map<String, dynamic>> uploadMedia({
    required Uint8List? bytes,
    required String? filePath,
    required String fileName,
    required String ownerType, // 'profile' | 'post' | 'story' | 'event' | 'chat' | 'report'
    required String idempotencyKey,
    required void Function(double progress) onProgress,
  });

  Future<Map<String, dynamic>?> checkDeduplication({
    required String hash,
    required String ownerType,
  });
}

class MediaUploadServiceImpl implements MediaUploadService {
  final CloudflareConfig _config;

  MediaUploadServiceImpl(this._config);

  @override
  Future<Map<String, dynamic>> uploadMedia({
    required Uint8List? bytes,
    required String? filePath,
    required String fileName,
    required String ownerType,
    required String idempotencyKey,
    required void Function(double progress) onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to upload media.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to obtain Firebase ID token.');
    }

    final url = Uri.parse('${_config.workerUrl}/upload');
    debugPrint('MediaUploadService: Initiating upload to: $url');

    final request = MultipartRequestWithProgress(
      'POST',
      url,
      onProgress: (bytesSent, totalBytes) {
        if (totalBytes > 0) {
          final progress = bytesSent / totalBytes;
          onProgress(progress);
        }
      },
    );

    // Setup headers required for tracking, security and validation on Worker
    request.headers['Authorization'] = 'Bearer $idToken';
    request.headers['X-Owner-Type'] = ownerType;
    request.headers['X-Idempotency-Key'] = idempotencyKey;
    final safeFileName = fileName.replaceAll(RegExp(r'[^\x00-\x7F]'), '_');
    request.headers['X-File-Name'] = safeFileName;

    int length = 0;
    final mediaType = _getMediaType(fileName);
    if (kIsWeb) {
      if (bytes == null) throw Exception('Web uploads require complete byte buffers.');
      length = bytes.length;
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: mediaType,
      );
      request.files.add(multipartFile);
    } else {
      if (filePath == null) throw Exception('Native uploads require file path.');
      final file = io.File(filePath);
      if (!await file.exists()) {
        throw Exception('Source file not found at path: $filePath');
      }
      length = await file.length();
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
        contentType: mediaType,
      );
      request.files.add(multipartFile);
    }

    request.headers['X-File-Size'] = length.toString();

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        debugPrint('MediaUploadService: Upload successful. Data: $responseData');
        return responseData;
      } else {
        final Map<String, dynamic> errData = json.decode(response.body);
        final errMsg = errData['error'] ?? 'Unknown network or API error';
        throw Exception('Server error (${response.statusCode}): $errMsg');
      }
    } catch (e) {
      debugPrint('MediaUploadService: Exception occurred: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> checkDeduplication({
    required String hash,
    required String ownerType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return null;

    final url = Uri.parse('${_config.workerUrl}/upload/check/$hash');
    debugPrint('MediaUploadService: Checking deduplication for hash: $hash');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
          'X-Owner-Type': ownerType,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['exists'] == true) {
          debugPrint('MediaUploadService: Deduplication hit! Media exists: ${data['media']}');
          return data;
        }
      }
    } catch (e) {
      debugPrint('MediaUploadService: Error during deduplication check: $e');
    }
    return null;
  }
}

String calculateSha256(Uint8List bytes) {
  return sha256.convert(bytes).toString();
}

MediaType _getMediaType(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  if (ext == 'jpg' || ext == 'jpeg') return MediaType('image', 'jpeg');
  if (ext == 'png') return MediaType('image', 'png');
  if (ext == 'webp') return MediaType('image', 'webp');
  if (ext == 'mp4') return MediaType('video', 'mp4');
  return MediaType('application', 'octet-stream');
}

final mediaUploadServiceProvider = Provider<MediaUploadService>((ref) {
  final config = ref.watch(cloudflareConfigProvider);
  return MediaUploadServiceImpl(config);
});
