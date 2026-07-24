import 'package:cloud_firestore/cloud_firestore.dart';

/// One-shot utility – call [seedFirestore] once from a dev button/screen to
/// populate the `posts` collection with sample posts and clips.
/// It is safe to call multiple times: it skips documents that already exist.
class FirestoreSeeder {
  static final _db = FirebaseFirestore.instance;

  // ── sample video / image URLs ───────────────────────────────────────────────
  static const _v1 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
  static const _v2 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4';
  static const _v3 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnTheRoadAgain.mp4';
  static const _v4 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4';
  static const _v5 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4';

  static const _t1 = 'https://images.unsplash.com/photo-1519861531473-9200262188bf?auto=format&fit=crop&w=800&q=80';
  static const _t2 = 'https://images.unsplash.com/photo-1560272564-c83b66b1ad12?auto=format&fit=crop&w=800&q=80';
  static const _t3 = 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80';
  static const _t4 = 'https://images.unsplash.com/photo-1543326727-cf6c39e8f84c?auto=format&fit=crop&w=800&q=80';
  static const _t5 = 'https://images.unsplash.com/photo-1540539234-c14a20fb7c7b?auto=format&fit=crop&w=800&q=80';

  static const _a1 = 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80';
  static const _a2 = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80';
  static const _a3 = 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80';
  static const _a4 = 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=150&q=80';
  static const _a5 = 'https://images.unsplash.com/photo-1463453091185-61582044d556?auto=format&fit=crop&w=150&q=80';

  static Future<void> seedFirestore() async {
    await Future.wait([_seedClips(), _seedPosts()]);
  }

  // ── clips ──────────────────────────────────────────────────────────────────
  static Future<void> _seedClips() async {
    final clips = [
      _clip('seed_clip_1', 'Early morning sprint drills – pace is everything', 'Jordan Vance', 'seed_user_1', _a1, true, 'Athletics', _v1, _t5),
      _clip('seed_clip_2', 'Footwork routine that changed my game', 'Priya Sharma', 'seed_user_2', _a3, true, 'Basketball', _v2, _t1),
      _clip('seed_clip_3', 'Full-body strength session – off-season prep', 'Marcus Osei', 'seed_user_3', _a2, false, 'Football', _v3, _t3),
      _clip('seed_clip_4', 'Pool recovery – why cold-water therapy works', 'Anika Reyes', 'seed_user_4', _a4, true, 'Swimming', _v4, _t4),
      _clip('seed_clip_5', 'Match highlights – regional quarter-final', 'Devon Carr', 'seed_user_5', _a5, false, 'Football', _v5, _t2),
    ];

    final batch = _db.batch();
    for (final clip in clips) {
      final ref = _db.collection('posts').doc(clip['id'] as String);
      final snap = await ref.get();
      if (!snap.exists) batch.set(ref, clip);
    }
    await batch.commit();
  }

  static Map<String, dynamic> _clip(
    String id, String title, String athlete, String athleteId,
    String avatar, bool verified, String sport,
    String mediaUrl, String thumbUrl,
  ) {
    return {
      'id': id,
      'type': 'clip',
      'userId': athleteId,
      'userName': athlete,
      'userAvatar': avatar,
      'verified': verified,
      'sport': sport,
      'position': 'Athlete',
      'content': title,
      'category': 'general',
      'likes': 0,
      'commentsCount': 0,
      'shares': 0,
      'bookmarks': 0,
      'views': 0,
      'media': [
        {
          'mediaUrl': mediaUrl,
          'mediaType': 'video',
          'thumbnailUrl': thumbUrl,
          'publicId': id,
          'width': 1080,
          'height': 1920,
          'duration': 15.0,
        }
      ],
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ── posts ──────────────────────────────────────────────────────────────────
  static Future<void> _seedPosts() async {
    final posts = [
      _post('seed_post_1', 'seed_user_1', 'Jordan Vance', _a1, true, 'Athletics', 'Sprinter',
          'Just wrapped up a personal-best 100 m in training — 10.42 s. Consistency beats intensity every single day. 🏃‍♂️',
          _v1, 'video', _t5, 'training'),
      _post('seed_post_2', 'seed_user_2', 'Priya Sharma', _a3, true, 'Basketball', 'Point Guard',
          'Footwork is the foundation. Before you focus on shooting or handles, lock in your footwork.',
          _t1, 'image', null, 'training'),
      _post('seed_post_3', 'seed_user_3', 'Marcus Osei', _a2, false, 'Football', 'Centre-Back',
          'Off-season strength block complete. 12 weeks of hard work in the gym. Coming back bigger, faster, and harder to beat. 💪',
          _v2, 'video', _t3, 'achievement'),
      _post('seed_post_4', 'seed_user_4', 'Anika Reyes', _a4, true, 'Swimming', 'Freestyle',
          'Recovery day. Ice bath + pool floats + stretching. You can\'t build on a broken foundation — rest is training.',
          _t4, 'image', null, 'recovery'),
      _post('seed_post_5', 'seed_user_5', 'Devon Carr', _a5, false, 'Football', 'Winger',
          'Buzzer-beater finish in the regional quarter-final. One more game to the final. 🔥',
          _v3, 'video', _t2, 'match'),
    ];

    final batch = _db.batch();
    for (final post in posts) {
      final ref = _db.collection('posts').doc(post['id'] as String);
      final snap = await ref.get();
      if (!snap.exists) batch.set(ref, post);
    }
    await batch.commit();
  }

  static Map<String, dynamic> _post(
    String id, String userId, String userName, String avatar, bool verified,
    String sport, String position, String content,
    String mediaUrl, String mediaType, String? thumbUrl, String category,
  ) {
    return {
      'id': id,
      'type': 'post',
      'userId': userId,
      'userName': userName,
      'userAvatar': avatar,
      'verified': verified,
      'sport': sport,
      'position': position,
      'content': content,
      'category': category,
      'likes': 0,
      'commentsCount': 0,
      'shares': 0,
      'bookmarks': 0,
      'views': 0,
      'media': [
        {
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'thumbnailUrl': thumbUrl,
          'publicId': id,
          'width': 1080,
          'height': 1080,
        }
      ],
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
