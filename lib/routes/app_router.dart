import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/security/presentation/screens/app_lock_screen.dart';
import '../features/settings/presentation/screens/about_screen.dart';
import '../features/settings/presentation/screens/help_support_screen.dart';
import '../features/settings/presentation/screens/language_screen.dart';
import '../features/settings/presentation/screens/privacy_settings_screen.dart';
import '../features/settings/presentation/screens/notification_settings_screen.dart';
import '../features/settings/presentation/screens/storage_data_screen.dart';
import '../features/settings/presentation/screens/theme_settings_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/calls/presentation/screens/call_screen.dart';
import '../features/calls/presentation/screens/call_history_screen.dart';
import '../features/stories/presentation/screens/stories_list_screen.dart';
import '../features/stories/presentation/screens/story_view_screen.dart';

/// Shared navigator key exposed so that [PushNotificationService] can drive
/// navigation from notification tap callbacks without needing a BuildContext.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/calls',
      builder: (context, state) => const CallHistoryScreen(),
    ),
    GoRoute(
      path: '/call/:callId',
      builder: (context, state) =>
          CallScreen(callId: state.pathParameters['callId'] ?? ''),
    ),
    GoRoute(
      path: '/stories',
      builder: (context, state) => const StoriesListScreen(),
    ),
    GoRoute(
      path: '/story/:storyId',
      builder: (context, state) =>
          StoryViewScreen(storyId: state.pathParameters['storyId'] ?? ''),
    ),
    GoRoute(
      path: '/lock',
      builder: (context, state) => const AppLockScreen(),
    ),
    GoRoute(
      path: '/privacy_settings',
      builder: (context, state) => const PrivacySettingsScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/notification_settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: '/theme_settings',
      builder: (context, state) => const ThemeSettingsScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/help_support',
      builder: (context, state) => const HelpSupportScreen(),
    ),
    GoRoute(
      path: '/language',
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/storage_data',
      builder: (context, state) => const StorageDataScreen(),
    ),
  ],
);
