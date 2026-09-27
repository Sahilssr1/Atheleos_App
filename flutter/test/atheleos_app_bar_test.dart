import 'package:atheleos/core/widgets/atheleos_app_bar.dart';
import 'package:atheleos/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtheleosAppBar', () {
    testWidgets('renders signature banner asset on the left and calendar outline icon for events', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: AtheleosAppBar(),
            ),
          ),
        ),
      );

      // Verify the signature banner asset is displayed
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as AssetImage).assetName, 'assets/images/atheleos_banner.png');

      // Verify AppBar is not centered (signature logo on the left)
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      final appBar = tester.widget<AppBar>(appBarFinder);
      expect(appBar.centerTitle, isFalse);

      // Verify Calendar outline icon replaces the trophy icon for events
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);

      // Verify notification bell and chat bubble icons
      expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    });

    testWidgets('renders custom title text when titleText is provided', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: AtheleosAppBar(titleText: 'CUSTOM TITLE'),
            ),
          ),
        ),
      );

      expect(find.text('CUSTOM TITLE'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('displays unread notification badge count when count > 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWith((ref) => Stream.value(5)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: AtheleosAppBar(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('renders without overflow on narrow screens (320px width)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWith((ref) => Stream.value(0)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: AtheleosAppBar(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    });
  });
}
