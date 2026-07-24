import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'core/services/cache_manager.dart';
import 'features/profile/presentation/controllers/settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap the global Flutter ImageCache so scrolling through hundreds of
  // posts can't grow the resident set forever. Values chosen to match a
  // typical short-form video app: ~150 decoded images / ~60 MB of RAM.
  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 << 20; // 60 MB

  await CacheManager().init();
  timezone_data.initializeTimeZones();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: AtheleosApp(),
    ),
  );
}

class AtheleosApp extends ConsumerWidget {
  const AtheleosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final themeMode = switch (preferences.theme) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'Atheleos',
      debugShowCheckedModeBanner: false,

      // Material 3 Dark theme (sports-centric, high contrast volt & slate style)
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: Locale(preferences.language),
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('pt'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // GoRouter Configuration
      routerConfig: router,
    );
  }
}
