import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atheleos/features/chat/presentation/widgets/share_content_bottom_sheet.dart';
import 'package:atheleos/features/profile/presentation/controllers/profile_controller.dart';
import 'package:atheleos/features/profile/domain/models/profile_model.dart';
import 'package:atheleos/features/chat/presentation/controllers/chat_controller.dart';

class FakeProfileListNotifier extends StateNotifier<AsyncValue<List<ProfileModel>>>
    implements ProfileListNotifier {
  FakeProfileListNotifier([List<ProfileModel> initial = const []])
      : super(AsyncValue.data(initial));

  @override
  Future<void> loadAllProfiles() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> updateProfile(ProfileModel updated) async {}
}

void main() {
  testWidgets('pumps ShareContentBottomSheet and verifies structure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileListProvider.overrideWith((ref) => FakeProfileListNotifier()),
          loggedInUserIdProvider.overrideWith((ref) => 'user_1'),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ShareContentBottomSheet(
              postId: 'post_1',
              shareType: 'post',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Share to Chat'), findsOneWidget);
  });
}
