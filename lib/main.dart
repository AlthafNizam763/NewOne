import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/appearance_provider.dart';
import 'config/theme.dart';
import 'routes/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/presence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final container = ProviderContainer();

  // init() is non-blocking — permission dialog and token fetch happen in the
  // background so runApp() is not delayed.
  await container.read(pushNotificationServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AnataNoTameNiApp(),
    ),
  );
}

class AnataNoTameNiApp extends ConsumerStatefulWidget {
  const AnataNoTameNiApp({super.key});

  @override
  ConsumerState<AnataNoTameNiApp> createState() => _AnataNoTameNiAppState();
}

class _AnataNoTameNiAppState extends ConsumerState<AnataNoTameNiApp> {
  @override
  void initState() {
    super.initState();
    // Wire notification taps → GoRouter navigation.
    // appRouter.go() works without a BuildContext since GoRouter holds its
    // own navigator state via rootNavigatorKey.
    // This callback fires for:
    //   • background→foreground taps  (onMessageOpenedApp)
    //   • foreground local notification taps  (flutter_local_notifications)
    // Terminated-state taps are handled separately in SplashScreen via
    // consumeInitialNotification().
    ref.read(pushNotificationServiceProvider).onNotificationTap = (data) {
      final type = data['type'] as String?;
      if (type == 'chat') {
        appRouter.go('/chat');
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(presenceServiceProvider).onUserActivity(),
      child: MaterialApp.router(
        title: 'Hisoka',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forAppearance(Brightness.light, appearance),
        darkTheme: AppTheme.forAppearance(Brightness.dark, appearance),
        themeMode: appearance.themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(appearance.fontScale),
          ),
          child: child!,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
