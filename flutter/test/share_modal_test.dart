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
  testWidgets('showModalBottomSheet with ShareContentBottomSheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileListProvider.overrideWith((ref) => FakeProfileListNotifier([
            ProfileModel.fromMap({
              'id': 'p1',
              'name': 'John Doe',
              'username': 'johndoe',
              'role': 'Athlete',
              'sport': 'Track',
            }),
          ])),
          loggedInUserIdProvider.overrideWith((ref) => 'user_1'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => const ShareContentBottomSheet(
                      postId: 'post_1',
                      reelId: 'post_1',
                      shareType: 'reel',
                    ),
                  );
                },
                child: const Text('Open Share'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Share to Chat'), findsOneWidget);
  });
}
