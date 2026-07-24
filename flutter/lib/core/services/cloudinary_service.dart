import 'dart:convert';
import 'dart:io' as io;
import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class CloudinaryConfig {
  final String cloudName;
  final String uploadPreset;
  final String apiKey;
  final String apiSecret;

  const CloudinaryConfig({
    required this.cloudName,
    required this.uploadPreset,
    this.apiKey = '',
    this.apiSecret = '',
  });
}

final cloudinaryConfigProvider = Provider<CloudinaryConfig>((ref) {
  // Use standard fallback defaults if compile-time environment flags are not provided
  const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: 'atheleos-cloud');
  const uploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: 'atheleos_unsigned');
  // Optional credentials required only for destructive operations (media deletion)
  const apiKey = String.fromEnvironment('CLOUDINARY_API_KEY', defaultValue: '');
  const apiSecret = String.fromEnvironment('CLOUDINARY_API_SECRET', defaultValue: '');

  return const CloudinaryConfig(
    cloudName: cloudName,
    uploadPreset: uploadPreset,
    apiKey: apiKey,
    apiSecret: apiSecret,
  );
});

abstract class CloudinaryService {
  Future<String> uploadImage({
    required Uint8List? bytes,
    required String? filePath,
    required String fileName,
  });

  Future<String> uploadVideo({
    required Uint8List? bytes,
    required String? filePath,
    required String fileName,
  });

  /// Deletes a media asset from Cloudinary.
  ///
  /// The public ID is resolved from [mediaUrl] when possible and falls back
  /// to [publicId]. Returns true when Cloudinary confirms the deletion.
  /// This is a best-effort operation: when API credentials are not
  /// configured it logs and returns false without throwing.
  Future<bool> deleteMedia({
    required String mediaUrl,
    String? publicId,
    required String resourceType, // 'image' | 'video'
  });
}

class CloudinaryServiceImpl implements CloudinaryService {
  final CloudinaryConfig _config;

  CloudinaryServiceImpl(this._config);

  @override
  Future<String> uploadImage({
    required Uint8List? bytes,
    required String? filePath,
    required String fileName,
  }) async {
    return _uploadFile(
      bytes: bytes,
      filePath: filePath,
      fileName: fileName,
      resourceType: 'image',
    );
  }

  @override
  Future<String> uploadVideo({
    required Uint8List? bytes,
    required String? filePath,
    required String fileName,
  }) async {
    return _uploadFile(
      bytes: bytes,
      filePath: filePath,
      fileName: fileName,
      resourceType: 'video',
    );
  }

  Future<String> _uploadFile({
    required Uint8List? bytes,
    required String? filePath,
    required String fileName,
    required String resourceType,
  }) async {
    if (_config.cloudName.isEmpty || _config.uploadPreset.isEmpty) {
      throw Exception('Cloudinary configuration is incomplete. Cloud name and upload preset must be specified.');
    }

    final url = Uri.parse('https://api.cloudinary.com/v1_1/${_config.cloudName}/$resourceType/upload');
    debugPrint('CloudinaryService: Initiating $resourceType upload to: $url');
    
    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _config.uploadPreset;

    if (kIsWeb) {
      if (bytes == null) throw Exception('Web uploads require complete byte buffers.');
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      );
      request.files.add(multipartFile);
    } else {
      if (filePath == null) throw Exception('Native platform uploads require a file path reference.');
      final file = io.File(filePath);
      if (!await file.exists()) {
        throw Exception('Source file not found at path: $filePath');
      }
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      );
      request.files.add(multipartFile);
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String? secureUrl = responseData['secure_url'];
        if (secureUrl != null) {
          debugPrint('CloudinaryService: Upload successful. URL: $secureUrl');
          return secureUrl;
        } else {
          throw Exception('Secure URL field is missing in Cloudinary JSON response.');
        }
      } else {
        final Map<String, dynamic> errData = json.decode(response.body);
        final errMsg = errData['error']?['message'] ?? 'Unknown network or API error';
        throw Exception('Cloudinary error response (${response.statusCode}): $errMsg');
      }
    } catch (e) {
      debugPrint('CloudinaryService: Exception occurred: $e');
      throw Exception('Failed to upload file to Cloudinary: $e');
    }
  }

  @override
  Future<bool> deleteMedia({
    required String mediaUrl,
    String? publicId,
    required String resourceType,
  }) async {
    if (_config.apiKey.isEmpty || _config.apiSecret.isEmpty) {
      debugPrint('CloudinaryService: Skipping media deletion — API credentials are not configured.');
      return false;
    }

    final resolvedPublicId = _extractPublicIdFromUrl(mediaUrl) ?? publicId;
    if (resolvedPublicId == null || resolvedPublicId.isEmpty) {
      debugPrint('CloudinaryService: Could not resolve public ID for media: $mediaUrl');
      return false;
    }

    final normalizedResourceType = resourceType == 'video' ? 'video' : 'image';
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Signature: SHA-1 over the alphabetically sorted params + API secret
    final signaturePayload = 'public_id=$resolvedPublicId&timestamp=$timestamp${_config.apiSecret}';
    final signature = sha1.convert(utf8.encode(signaturePayload)).toString();

    final url = Uri.parse('https://api.cloudinary.com/v1_1/${_config.cloudName}/$normalizedResourceType/destroy');

    try {
      final response = await http.post(url, body: {
        'public_id': resolvedPublicId,
        'api_key': _config.apiKey,
        'timestamp': '$timestamp',
        'signature': signature,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final result = data['result'] as String?;
        debugPrint('CloudinaryService: Deletion of "$resolvedPublicId" result: $result');
        return result == 'ok';
      }
      debugPrint('CloudinaryService: Deletion failed (${response.statusCode}): ${response.body}');
      return false;
    } catch (e) {
      debugPrint('CloudinaryService: Deletion exception: $e');
      return false;
    }
  }

  /// Extracts a Cloudinary public ID from a delivery URL, e.g.
  /// https://res.cloudinary.com/demo/image/upload/v123/folder/name.jpg -> folder/name
  String? _extractPublicIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('cloudinary.com')) return null;

    final segments = List<String>.from(uri.pathSegments);
    final uploadIndex = segments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex >= segments.length - 1) return null;

    var rest = segments.sublist(uploadIndex + 1);
    // Drop transformation segments (contain commas) and the version segment (v123456)
    while (rest.isNotEmpty && (rest.first.contains(',') || RegExp(r'^v\d+$').hasMatch(rest.first))) {
      rest = rest.sublist(1);
    }
    if (rest.isEmpty) return null;

    final fileName = rest.last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
    return [...rest.sublist(0, rest.length - 1), baseName].join('/');
  }
}

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  final config = ref.watch(cloudinaryConfigProvider);
  return CloudinaryServiceImpl(config);
});
