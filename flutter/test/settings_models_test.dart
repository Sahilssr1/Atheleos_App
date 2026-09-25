import 'package:atheleos/features/profile/domain/models/profile_model.dart';
import 'package:atheleos/features/profile/domain/models/user_settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings models', () {
    test('migrates legacy verified messaging access to followers', () {
      final settings = MessagingSettings.fromMap({
        'allowedSenders': 'verified',
      });

      expect(settings.allowedSenders, 'followers');
    });

    test('migrates removed nobody messaging access to followers', () {
      final settings = MessagingSettings.fromMap({
        'allowedSenders': 'nobody',
      });

      expect(settings.allowedSenders, 'followers');
    });

    test('privacy masking can explicitly clear nullable measurements', () {
      const profile = ProfileModel(
        id: 'user-1',
        name: 'Athlete',
        username: 'athlete',
        avatarUrl: '',
        coverUrl: '',
        role: 'Athlete',
        verified: false,
        sport: 'Football',
        primaryPosition: 'Forward',
        clubOrAcademy: '',
        city: '',
        state: '',
        bio: '',
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        clipsCount: 0,
        achievements: [],
        certifications: [],
        website: '',
        socialLinks: {},
        height: 180,
        weight: 75,
        mediaGallery: [],
      );

      final masked = profile.copyWith(height: null, weight: null);
      final unchanged = profile.copyWith();

      expect(masked.height, isNull);
      expect(masked.weight, isNull);
      expect(unchanged.height, 180);
      expect(unchanged.weight, 75);
    });
  });
}
