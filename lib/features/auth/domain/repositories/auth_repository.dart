import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;

  /// Register a recovery email to create two paired accounts with auto-generated usernames.
  /// Returns the credentials map: user1_name, user2_name, password.
  Future<Map<String, String>> registerPair(String email);

  /// Login with generated username and password
  Future<void> loginWithUsername(String username, String password);

  Future<void> signOut();
  Future<UserModel?> getUserProfile(String uid);
  Future<void> updateOnlineStatus(String uid, bool isOnline);
}
