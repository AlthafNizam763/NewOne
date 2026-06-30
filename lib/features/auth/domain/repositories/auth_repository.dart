import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;

  /// Check whether a username is available (not already taken in Firestore).
  /// The check is case-insensitive — usernames are normalised to lowercase.
  /// Returns true if the username can be used.
  Future<bool> isUsernameAvailable(String username);

  /// Register a recovery email plus two chosen usernames to create a paired
  /// account. Throws a descriptive [Exception] if:
  ///   • the email is already registered
  ///   • either username is already taken
  ///   • both usernames are identical
  /// Returns the credentials map: user1_name, user2_name, password.
  Future<Map<String, String>> registerPair(
      String email, String username1, String username2);

  /// Login with username and password.
  Future<void> loginWithUsername(String username, String password);

  Future<void> signOut();
  Future<UserModel?> getUserProfile(String uid);
  Future<void> updateOnlineStatus(String uid, bool isOnline);
}
