import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralises app-icon badge count management across all app states.
///
/// Architecture
/// ─────────────
/// • SharedPreferences  — local integer cache; fast, survives hot-restart.
/// • Firestore users/{uid}.unreadCount — server-side source of truth.
///   Background isolates (FCM handler) can write here; platform channels
///   (AppBadgePlus) are NOT available in background isolates.
/// • AppBadgePlus — platform API: Android launcher badge / iOS UIKit badge.
///   Only called from the foreground (UI isolate).
class BadgeService {
  static const _prefKey = 'hisoka_badge_count';

  // ── Local helpers ───────────────────────────────────────────────────────

  static Future<int> _localCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_prefKey) ?? 0;
  }

  static Future<void> _setLocal(int n) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefKey, n);
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Returns the locally cached badge count (fast, no network call).
  static Future<int> getCount() => _localCount();

  /// Sets the launcher icon badge to [count] and persists it locally.
  /// Safe to call from the UI isolate only.
  static Future<void> setCount(int count) async {
    if (kIsWeb) return;
    try {
      final n = count.clamp(0, 99999);
      await _setLocal(n);
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(n);
      }
    } catch (e) {
      debugPrint('[Badge] setCount error: $e');
    }
  }

  /// Increments the local badge by 1 and mirrors the change to Firestore.
  /// Call from the UI isolate when a foreground FCM notification arrives.
  static Future<void> increment() async {
    if (kIsWeb) return;
    try {
      final n = await _localCount() + 1;
      await setCount(n);
      await _firestoreIncrement();
    } catch (e) {
      debugPrint('[Badge] increment error: $e');
    }
  }

  /// Clears the badge (sets to 0) and resets the Firestore counter.
  /// Call when the user opens the chat or dismisses all notifications.
  static Future<void> clear() async {
    if (kIsWeb) return;
    try {
      await setCount(0);
      await _firestoreClear();
    } catch (e) {
      debugPrint('[Badge] clear error: $e');
    }
  }

  /// Reads unreadCount from Firestore and syncs the local badge icon.
  /// Call when the app resumes from background or terminated state so the
  /// badge reflects increments that happened while the app was not in the
  /// foreground (written by [firestoreIncrementInBackground]).
  static Future<void> syncFromFirestore() async {
    if (kIsWeb) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final count = (snap.data()?['unreadCount'] as int?) ?? 0;
      await setCount(count);
    } catch (e) {
      debugPrint('[Badge] syncFromFirestore error: $e');
    }
  }

  /// Increments server-side unread count in Firestore.
  ///
  /// This is the ONLY badge operation safe to call from a background isolate
  /// (e.g., inside [_firebaseMessagingBackgroundHandler]) because it uses
  /// Firestore — not platform channels — and Firebase is already initialised
  /// there. AppBadgePlus cannot be called in background isolates.
  static Future<void> firestoreIncrementInBackground() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'unreadCount': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Badge] firestoreIncrementInBackground error: $e');
    }
  }

  // ── Internal Firestore helpers ──────────────────────────────────────────

  static Future<void> _firestoreIncrement() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'unreadCount': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Badge] _firestoreIncrement error: $e');
    }
  }

  static Future<void> _firestoreClear() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'unreadCount': 0});
    } catch (e) {
      debugPrint('[Badge] _firestoreClear error: $e');
    }
  }
}
