import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;

  /// Register an email and base username to create two paired accounts
  /// Returns the credentials to be shown
  Future<Map<String, String>> registerPair(String email, String baseUsername);

  /// Login with generated username and password
  Future<void> loginWithUsername(String username, String password);

  Future<void> signOut();
  Future<UserModel?> getUserProfile(String uid);
  Future<void> updateOnlineStatus(String uid, bool isOnline);
}
