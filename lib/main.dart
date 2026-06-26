import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/theme_mode_provider.dart';
import 'routes/app_router.dart';
import 'core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Riverpod Container
  final container = ProviderContainer();

  // Initialize Push Notifications
  await container.read(pushNotificationServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AnataNoTameNiApp(),
    ),
  );
}

class AnataNoTameNiApp extends ConsumerWidget {
  const AnataNoTameNiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp.router(
      title: 'Hisoka',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
