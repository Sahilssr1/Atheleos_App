import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class CacheManager {
  static const String _feedKey = 'cached_feed_posts';
  static const String _exploreKey = 'cached_explore_posts';
  static const String _profilesKeyPrefix = 'cached_profile_';
  static const String _commentsKeyPrefix = 'cached_comments_';
  static const String _searchHistoryKey = 'cached_search_history';
  static const String _userLikesKeyPrefix = 'cached_user_likes_';
  static const String _userBookmarksKeyPrefix = 'cached_user_bookmarks_';

  // Video Cache Configuration
  static const int maxVideoCacheSize = 1024 * 1024 * 1024; // 1 GB in bytes
  static const String _videoCacheMetaKey = 'video_cache_meta_lru';

  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  SharedPreferences? _prefs;

  // Video preload concurrency control:
  //  * `_inFlightDownloads` de-duplicates: multiple call sites for the same
  //    URL share a single Future instead of spawning parallel HTTP requests.
  //  * `_downloadSemaphore` caps the number of ACTIVE downloads so preloading
  //    never buffers more than a couple of videos worth of bytes at a time.
  final Map<String, Future<String?>> _inFlightDownloads = {};
  static const int _maxConcurrentVideoDownloads = 2;
  int _activeDownloads = 0;
  final List<Completer<void>> _downloadWaiters = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('CacheManager not initialized. Call init() first.');
    }
    return _prefs!;
  }

  Future<void> saveFeed(List<Map<String, dynamic>> posts) async {
    final list = posts.take(25).toList(); // Capped to 25 latest for instant cold start without disk stalls
    await prefs.setString(_feedKey, json.encode(list, toEncodable: _customJsonEncoder));
  }

  /// Load feed posts
  List<Map<String, dynamic>> loadFeed() {
    final data = prefs.getString(_feedKey);
    if (data == null) return [];
    try {
      final List decoded = json.decode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Save explore posts
  Future<void> saveExplore(List<Map<String, dynamic>> posts) async {
    final list = posts.take(30).toList(); // Capped to 30 explore items
    await prefs.setString(_exploreKey, json.encode(list, toEncodable: _customJsonEncoder));
  }

  /// Load explore posts
  List<Map<String, dynamic>> loadExplore() {
    final data = prefs.getString(_exploreKey);
    if (data == null) return [];
    try {
      final List decoded = json.decode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Save profile details
  Future<void> saveProfile(
      String userId, Map<String, dynamic> profileData) async {
    await prefs.setString(
        '$_profilesKeyPrefix$userId', json.encode(profileData, toEncodable: _customJsonEncoder));
    // Maintain list of cached profile IDs for LRU / limit eviction if needed
    final List<String> cachedIds =
        prefs.getStringList('cached_profile_ids') ?? [];
    cachedIds.remove(userId);
    cachedIds.insert(0, userId); // Add to head
    // Evict oldest if limit exceeded (100 profiles)
    if (cachedIds.length > 100) {
      final oldest = cachedIds.removeLast();
      await prefs.remove('$_profilesKeyPrefix$oldest');
    }
    await prefs.setStringList('cached_profile_ids', cachedIds);
  }

  /// Load profile details
  Map<String, dynamic>? loadProfile(String userId) {
    final data = prefs.getString('$_profilesKeyPrefix$userId');
    if (data == null) return null;
    try {
      return json.decode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Save comments for a specific post
  Future<void> saveComments(
      String postId, List<Map<String, dynamic>> comments) async {
    await prefs.setString('$_commentsKeyPrefix$postId', json.encode(comments, toEncodable: _customJsonEncoder));
  }

  /// Load comments for a specific post
  List<Map<String, dynamic>> loadComments(String postId) {
    final data = prefs.getString('$_commentsKeyPrefix$postId');
    if (data == null) return [];
    try {
      final List decoded = json.decode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Save search history
  Future<void> saveSearchHistory(List<String> history) async {
    await prefs.setStringList(_searchHistoryKey, history);
  }

  /// Load search history
  List<String> loadSearchHistory() {
    return prefs.getStringList(_searchHistoryKey) ?? [];
  }

  /// Save user's liked post IDs for instant cold-start restore
  Future<void> saveLikedPostIds(String userId, Set<String> likedIds) async {
    if (userId.isEmpty) return;
    await prefs.setStringList('$_userLikesKeyPrefix$userId', likedIds.toList());
  }

  /// Load user's liked post IDs
  Set<String> loadLikedPostIds(String userId) {
    if (userId.isEmpty) return {};
    final list = prefs.getStringList('$_userLikesKeyPrefix$userId');
    return list != null ? list.toSet() : {};
  }

  /// Optimistically add a liked post ID to local cache
  Future<void> addLikedPostId(String userId, String postId) async {
    if (userId.isEmpty || postId.isEmpty) return;
    final current = loadLikedPostIds(userId);
    current.add(postId);
    await saveLikedPostIds(userId, current);
  }

  /// Optimistically remove a liked post ID from local cache
  Future<void> removeLikedPostId(String userId, String postId) async {
    if (userId.isEmpty || postId.isEmpty) return;
    final current = loadLikedPostIds(userId);
    current.remove(postId);
    await saveLikedPostIds(userId, current);
  }

  /// Save user's bookmarked post IDs
  Future<void> saveBookmarkedPostIds(String userId, Set<String> bookmarkedIds) async {
    if (userId.isEmpty) return;
    await prefs.setStringList('$_userBookmarksKeyPrefix$userId', bookmarkedIds.toList());
  }

  /// Load user's bookmarked post IDs
  Set<String> loadBookmarkedPostIds(String userId) {
    if (userId.isEmpty) return {};
    final list = prefs.getStringList('$_userBookmarksKeyPrefix$userId');
    return list != null ? list.toSet() : {};
  }

  /// Optimistically add a bookmarked post ID to local cache
  Future<void> addBookmarkedPostId(String userId, String postId) async {
    if (userId.isEmpty || postId.isEmpty) return;
    final current = loadBookmarkedPostIds(userId);
    current.add(postId);
    await saveBookmarkedPostIds(userId, current);
  }

  /// Optimistically remove a bookmarked post ID from local cache
  Future<void> removeBookmarkedPostId(String userId, String postId) async {
    if (userId.isEmpty || postId.isEmpty) return;
    final current = loadBookmarkedPostIds(userId);
    current.remove(postId);
    await saveBookmarkedPostIds(userId, current);
  }

  static const String _chatListKey = 'cached_chat_list';
  static const String _chatMessagesKeyPrefix = 'cached_chat_msg_';

  /// Save direct message chat list
  Future<void> saveChatList(List<Map<String, dynamic>> rooms) async {
    await prefs.setString(_chatListKey, json.encode(rooms, toEncodable: _customJsonEncoder));
  }

  /// Load direct message chat list
  List<Map<String, dynamic>> loadChatList() {
    final data = prefs.getString(_chatListKey);
    if (data == null) return [];
    try {
      final List decoded = json.decode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Save direct messages for a specific room
  Future<void> saveRoomMessages(
      String roomId, List<Map<String, dynamic>> messages) async {
    // Save up to 50 latest messages to prevent massive storage bloating
    final list = messages.take(50).toList();
    await prefs.setString('$_chatMessagesKeyPrefix$roomId', json.encode(list, toEncodable: _customJsonEncoder));
  }

  /// Load direct messages for a specific room
  List<Map<String, dynamic>> loadRoomMessages(String roomId) {
    final data = prefs.getString('$_chatMessagesKeyPrefix$roomId');
    if (data == null) return [];
    try {
      final List decoded = json.decode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearAll() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.clear();
    } catch (e) {
      debugPrint('CacheManager clearAll prefs error: $e');
    }
    try {
      final cacheDir = await _getVideoCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // OFFLINE VIDEO CACHING (LRU Eviction up to 1GB)
  // ═══════════════════════════════════════════════════════════════════

  /// Helper to hash URL to avoid bad file system characters
  String _hashUrl(String url) {
    return sha256.convert(utf8.encode(url)).toString();
  }

  /// Get the directory where cached videos are saved
  Future<Directory> _getVideoCacheDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${docDir.path}/video_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Get local path of cached video if it exists
  Future<String?> getCachedVideoPath(String url) async {
    if (url.isEmpty) return null;
    try {
      final cacheDir = await _getVideoCacheDir();
      final hashed = _hashUrl(url);
      final ext = url.split('.').last.split('?').first;
      final file = File('${cacheDir.path}/$hashed.$ext');

      if (await file.exists()) {
        _updateVideoAccessTime(url);
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  /// Get or fetch video locally (caching it in the process)
  Future<String> getOrCacheVideo(String url,
      {void Function(double)? onProgress}) async {
    final cached = await getCachedVideoPath(url);
    if (cached != null) {
      return cached;
    }

    final downloaded = await _downloadVideoDeduped(url);
    return downloaded ?? url;
  }

  /// Preload video silently without blocking.
  ///
  /// Instagram-style single-video-ahead prefetching relies on this staying
  /// cheap: it must NEVER hold the entire video in memory (streaming write)
  /// and MUST de-duplicate parallel requests for the same URL.
  Future<void> preloadVideo(String url) async {
    if (url.isEmpty) return;
    final cached = await getCachedVideoPath(url);
    if (cached != null) return; // already cached
    // Fire-and-forget, but reuse the in-flight Future if one already exists.
    unawaited(_downloadVideoDeduped(url));
  }

  /// De-duplicated + concurrency-limited streaming download.
  ///
  /// Returns the local file path on success, `null` on failure.
  Future<String?> _downloadVideoDeduped(String url) {
    final existing = _inFlightDownloads[url];
    if (existing != null) return existing;

    final future = _downloadVideoStreaming(url).whenComplete(() {
      _inFlightDownloads.remove(url);
    });
    _inFlightDownloads[url] = future;
    return future;
  }

  Future<void> _acquireDownloadSlot() async {
    if (_activeDownloads < _maxConcurrentVideoDownloads) {
      _activeDownloads++;
      return;
    }
    final completer = Completer<void>();
    _downloadWaiters.add(completer);
    await completer.future;
    _activeDownloads++;
  }

  void _releaseDownloadSlot() {
    _activeDownloads--;
    if (_downloadWaiters.isNotEmpty) {
      final next = _downloadWaiters.removeAt(0);
      next.complete();
    }
  }

  Future<String?> _downloadVideoStreaming(String url) async {
    await _acquireDownloadSlot();
    http.Client? client;
    File? tempFile;
    try {
      final cacheDir = await _getVideoCacheDir();
      final hashed = _hashUrl(url);
      final ext = url.split('.').last.split('?').first;
      final finalPath = '${cacheDir.path}/$hashed.$ext';
      final finalFile = File(finalPath);

      // If the file appeared in the meantime, just use it.
      if (await finalFile.exists()) {
        _updateVideoAccessTime(url);
        return finalFile.path;
      }

      // Write to a temp file first so a partial/interrupted download never
      // leaves the cache with a corrupt entry that video_player would fail on.
      tempFile = File('$finalPath.part');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        return null;
      }

      final sink = tempFile.openWrite();
      try {
        await response.stream.pipe(sink);
      } finally {
        // pipe closes the sink, but be defensive if it threw before piping.
        try {
          await sink.close();
        } catch (_) {}
      }

      await tempFile.rename(finalPath);
      _updateVideoAccessTime(url);
      // Fire-and-forget cleanup so a slow eviction pass never blocks caller.
      unawaited(_evictOldVideosIfNeeded());
      return finalPath;
    } catch (e) {
      debugPrint('Error streaming video cache: $e');
      // Best-effort cleanup of partial file.
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      return null;
    } finally {
      client?.close();
      _releaseDownloadSlot();
    }
  }

  /// Store metadata about video access timestamps for LRU policy
  void _updateVideoAccessTime(String url) {
    try {
      final String metaStr = prefs.getString(_videoCacheMetaKey) ?? '{}';
      final Map<String, dynamic> meta =
          json.decode(metaStr) as Map<String, dynamic>;
      meta[url] = DateTime.now().millisecondsSinceEpoch;
      prefs.setString(_videoCacheMetaKey, json.encode(meta));
    } catch (_) {}
  }

  /// LRU Cache Eviction implementation
  Future<void> _evictOldVideosIfNeeded() async {
    try {
      final cacheDir = await _getVideoCacheDir();
      final List<FileSystemEntity> files = cacheDir.listSync();
      int totalSize = 0;
      for (final f in files) {
        if (f is File) {
          totalSize += await f.length();
        }
      }

      if (totalSize <= maxVideoCacheSize) return;

      // Exceeded limit: evict oldest
      final String metaStr = prefs.getString(_videoCacheMetaKey) ?? '{}';
      final Map<String, dynamic> meta =
          json.decode(metaStr) as Map<String, dynamic>;

      // Map local file to access timestamp
      final List<MapEntry<FileSystemEntity, int>> filesWithTime = [];
      for (final f in files) {
        if (f is File) {
          // find key matching the filename hash
          final name = f.path.split('/').last.split('.').first;
          // look up time in meta
          String? matchingUrl;
          for (final entry in meta.entries) {
            if (sha256.convert(utf8.encode(entry.key)).toString() == name) {
              matchingUrl = entry.key;
              break;
            }
          }
          final time =
              matchingUrl != null ? (meta[matchingUrl] as int? ?? 0) : 0;
          filesWithTime.add(MapEntry(f, time));
        }
      }

      // Sort oldest first
      filesWithTime.sort((a, b) => a.value.compareTo(b.value));

      for (final entry in filesWithTime) {
        if (totalSize <= maxVideoCacheSize * 0.8) break; // keep at 80% capacity
        final file = entry.key;
        final size = await (file as File).length();
        await file.delete();
        totalSize -= size;

        // remove from meta
        final name = file.path.split('/').last.split('.').first;
        meta.removeWhere(
            (url, _) => sha256.convert(utf8.encode(url)).toString() == name);
      }

      prefs.setString(_videoCacheMetaKey, json.encode(meta));
    } catch (e) {
      debugPrint('LRU Video Eviction failed: $e');
    }
  }

  Object? _customJsonEncoder(dynamic item) {
    if (item is Timestamp) {
      return item.toDate().toIso8601String();
    }
    if (item is DateTime) {
      return item.toIso8601String();
    }
    return item.toString();
  }
}
