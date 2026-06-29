import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared state for the "notify me when partner comes online" feature.
/// Read by HomeScreen (nav button + notification trigger) and ChatScreen
/// (in-app snackbar trigger).
final notifyWhenOnlineProvider = StateProvider<bool>((ref) => false);
