import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atheleos/core/services/cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheManager().init();
  });

  test('CacheManager saves and loads user liked post IDs', () async {
    final cache = CacheManager();
    const userId = 'user_abc';

    expect(cache.loadLikedPostIds(userId), isEmpty);

    await cache.saveLikedPostIds(userId, {'post_1', 'post_2'});
    expect(cache.loadLikedPostIds(userId), {'post_1', 'post_2'});

    await cache.addLikedPostId(userId, 'post_3');
    expect(cache.loadLikedPostIds(userId), {'post_1', 'post_2', 'post_3'});

    await cache.removeLikedPostId(userId, 'post_1');
    expect(cache.loadLikedPostIds(userId), {'post_2', 'post_3'});
  });

  test('CacheManager saves and loads user bookmarked post IDs', () async {
    final cache = CacheManager();
    const userId = 'user_xyz';

    expect(cache.loadBookmarkedPostIds(userId), isEmpty);

    await cache.saveBookmarkedPostIds(userId, {'post_10'});
    expect(cache.loadBookmarkedPostIds(userId), {'post_10'});

    await cache.addBookmarkedPostId(userId, 'post_20');
    expect(cache.loadBookmarkedPostIds(userId), {'post_10', 'post_20'});

    await cache.removeBookmarkedPostId(userId, 'post_10');
    expect(cache.loadBookmarkedPostIds(userId), {'post_20'});
  });
}
