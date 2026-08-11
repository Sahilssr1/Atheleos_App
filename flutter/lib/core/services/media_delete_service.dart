import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'media_upload_service.dart';

abstract class MediaDeleteService {
  Future<void> softDeleteMedia(String mediaId);
  Future<void> cancelUpload(String mediaId);
}

class MediaDeleteServiceImpl implements MediaDeleteService {
  final CloudflareConfig _config;

  MediaDeleteServiceImpl(this._config);

  @override
  Future<void> softDeleteMedia(String mediaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to delete media.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to obtain Firebase ID token.');
    }

    final url = Uri.parse('${_config.workerUrl}/media/$mediaId');
    debugPrint('MediaDeleteService: Soft-deleting media: $mediaId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode != 200) {
        final Map<String, dynamic> errData = json.decode(response.body);
        final errMsg = errData['error'] ?? 'Unknown deletion error';
        throw Exception('Server error (${response.statusCode}): $errMsg');
      }
      debugPrint('MediaDeleteService: Soft-delete successful for mediaId: $mediaId');
    } catch (e) {
      debugPrint('MediaDeleteService: Failed to delete media: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelUpload(String mediaId) async {
    // Immediate cancellation of active uploads/temp files
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return;

    final url = Uri.parse('${_config.workerUrl}/upload/cancel');
    debugPrint('MediaDeleteService: Cancelling upload for mediaId: $mediaId');

    try {
      await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'mediaId': mediaId}),
      );
    } catch (e) {
      debugPrint('MediaDeleteService: Cancel upload error: $e');
    }
  }
}

final mediaDeleteServiceProvider = Provider<MediaDeleteService>((ref) {
  final config = ref.watch(cloudflareConfigProvider);
  return MediaDeleteServiceImpl(config);
});
