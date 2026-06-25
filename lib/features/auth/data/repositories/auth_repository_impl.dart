import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl(this._auth, this._firestore);

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  String _generateSecurePassword() {
    const lowers = 'abcdefghijklmnopqrstuvwxyz';
    const uppers = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    Random rnd = Random();

    String pass = '';
    pass += uppers[rnd.nextInt(uppers.length)];
    pass += lowers[rnd.nextInt(lowers.length)];
    pass += numbers[rnd.nextInt(numbers.length)];

    const allChars = lowers + uppers + numbers;
    for (int i = 0; i < 5; i++) {
      pass += allChars[rnd.nextInt(allChars.length)];
    }

    // Shuffle
    List<String> chars = pass.split('');
    chars.shuffle(rnd);
    return chars.join('');
  }

  @override
  Future<Map<String, String>> registerPair(
      String email, String baseUsername) async {
    final emailLower = email.toLowerCase().trim();
    final username1 = baseUsername.trim();
    final username2 = '${username1}Antn';

    // 1. Check uniqueness of email and usernames
    final regDoc =
        await _firestore.collection('registrations').doc(emailLower).get();
    if (regDoc.exists) {
      throw Exception('This email is already registered.');
    }

    final q1 = await _firestore
        .collection('users')
        .where('username', isEqualTo: username1)
        .get();
    final q2 = await _firestore
        .collection('users')
        .where('username', isEqualTo: username2)
        .get();

    if (q1.docs.isNotEmpty || q2.docs.isNotEmpty) {
      throw Exception(
          'Username "$baseUsername" is already taken. Please choose another.');
    }

    // 2. Generate Shared Password
    final password = _generateSecurePassword();

    final user1Email = '$username1@hisoka.com'.toLowerCase();
    final user2Email = '$username2@hisoka.com'.toLowerCase();

    // 3. Create Firebase Auth Accounts
    final u1Cred = await _auth.createUserWithEmailAndPassword(
        email: user1Email, password: password);
    final uid1 = u1Cred.user!.uid;

    final u2Cred = await _auth.createUserWithEmailAndPassword(
        email: user2Email, password: password);
    final uid2 = u2Cred.user!.uid;

    // 4. Save to Firestore
    final batch = _firestore.batch();

    // Registration Doc
    batch.set(_firestore.collection('registrations').doc(emailLower), {
      'createdAt': FieldValue.serverTimestamp(),
      'username1': username1,
      'username2': username2,
    });

    final pairRef = _firestore.collection('pairs').doc();
    batch.set(pairRef, {
      'pairId': pairRef.id,
      'username1': username1,
      'username2': username2,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final user1 = UserModel(
      uid: uid1,
      username: username1,
      registeredEmail:
          pairRef.id, // Recycled field to prevent breaking freezed models
      partnerUid: uid2,
      isOnline: false,
    );
    batch.set(_firestore.collection('users').doc(uid1), user1.toJson());

    final user2 = UserModel(
      uid: uid2,
      username: username2,
      registeredEmail: pairRef.id,
      partnerUid: uid1,
      isOnline: false,
    );
    batch.set(_firestore.collection('users').doc(uid2), user2.toJson());

    final roomId = uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
    batch.set(_firestore.collection('chat_rooms').doc(roomId), {
      'participants': [uid1, uid2],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Re-authenticate as user1 so the creator is automatically logged in correctly
    await _auth.signInWithEmailAndPassword(
        email: user1Email, password: password);

    return {
      'user1_name': username1,
      'user2_name': username2,
      'password': password,
    };
  }

  @override
  Future<void> loginWithUsername(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();

    try {
      // First attempt: Try logging in with the new domain
      final newEmail = '$cleanUsername@hisoka.com';
      await _auth.signInWithEmailAndPassword(
          email: newEmail, password: password);
    } on FirebaseAuthException catch (e) {
      // If it fails because the account doesn't exist with the new domain, try the legacy domain
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        try {
          final legacyEmail = '$cleanUsername@anatanotameni.local';
          await _auth.signInWithEmailAndPassword(
              email: legacyEmail, password: password);
        } catch (legacyError) {
          // If the legacy domain also fails, throw the original error
          throw Exception('Invalid username or password.');
        }
      } else {
        rethrow;
      }
    }

    // Set online status
    if (_auth.currentUser != null) {
      await updateOnlineStatus(_auth.currentUser!.uid, true);
    }
  }

  @override
  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      await updateOnlineStatus(_auth.currentUser!.uid, false);
    }
    await _auth.signOut();
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromJson(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
    });
  }
}
