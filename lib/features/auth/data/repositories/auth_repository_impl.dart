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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _generateSecurePassword() {
    const lowers = 'abcdefghijklmnopqrstuvwxyz';
    const uppers = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    final rnd = Random();

    String pass = '';
    pass += uppers[rnd.nextInt(uppers.length)];
    pass += lowers[rnd.nextInt(lowers.length)];
    pass += numbers[rnd.nextInt(numbers.length)];

    const allChars = lowers + uppers + numbers;
    for (int i = 0; i < 5; i++) {
      pass += allChars[rnd.nextInt(allChars.length)];
    }

    final chars = pass.split('');
    chars.shuffle(rnd);
    return chars.join('');
  }

  // ── isUsernameAvailable ───────────────────────────────────────────────────

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final q = await _firestore
        .collection('users')
        .where('username', isEqualTo: normalized)
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  // ── registerPair ──────────────────────────────────────────────────────────

  @override
  Future<Map<String, String>> registerPair(
      String email, String username1, String username2) async {
    final emailLower = email.toLowerCase().trim();
    // Normalise to lowercase — Firebase Auth emails are always lowercase
    final u1 = username1.trim().toLowerCase();
    final u2 = username2.trim().toLowerCase();

    // 1. Email must not already be registered
    final regDoc =
        await _firestore.collection('registrations').doc(emailLower).get();
    if (regDoc.exists) {
      throw Exception('This email is already registered.');
    }

    // 2. Both usernames must be distinct
    if (u1 == u2) {
      throw Exception('User 1 and User 2 must have different usernames.');
    }

    // 3. Both usernames must be available (race-condition guard)
    final q1 = await _firestore
        .collection('users')
        .where('username', isEqualTo: u1)
        .limit(1)
        .get();
    if (q1.docs.isNotEmpty) {
      throw Exception('Username "$u1" was just taken. Please choose another.');
    }

    final q2 = await _firestore
        .collection('users')
        .where('username', isEqualTo: u2)
        .limit(1)
        .get();
    if (q2.docs.isNotEmpty) {
      throw Exception('Username "$u2" was just taken. Please choose another.');
    }

    // 4. Shared password
    final password = _generateSecurePassword();

    final user1Email = '$u1@hisoka.com';
    final user2Email = '$u2@hisoka.com';

    // 5. Create Firebase Auth accounts
    final u1Cred = await _auth.createUserWithEmailAndPassword(
        email: user1Email, password: password);
    final uid1 = u1Cred.user!.uid;

    final u2Cred = await _auth.createUserWithEmailAndPassword(
        email: user2Email, password: password);
    final uid2 = u2Cred.user!.uid;

    // 6. Write to Firestore in one batch
    final batch = _firestore.batch();

    batch.set(_firestore.collection('registrations').doc(emailLower), {
      'createdAt': FieldValue.serverTimestamp(),
      'username1': u1,
      'username2': u2,
    });

    final pairRef = _firestore.collection('pairs').doc();
    batch.set(pairRef, {
      'pairId': pairRef.id,
      'username1': u1,
      'username2': u2,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final user1 = UserModel(
      uid: uid1,
      username: u1,
      registeredEmail: pairRef.id,
      partnerUid: uid2,
      isOnline: false,
    );
    batch.set(_firestore.collection('users').doc(uid1), user1.toJson());

    final user2 = UserModel(
      uid: uid2,
      username: u2,
      registeredEmail: pairRef.id,
      partnerUid: uid1,
      isOnline: false,
    );
    batch.set(_firestore.collection('users').doc(uid2), user2.toJson());

    final roomId =
        uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
    batch.set(_firestore.collection('chat_rooms').doc(roomId), {
      'participants': [uid1, uid2],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 7. Sign in as user1 so the registering device is immediately active
    await _auth.signInWithEmailAndPassword(
        email: user1Email, password: password);

    return {
      'user1_name': u1,
      'user2_name': u2,
      'password': password,
    };
  }

  // ── loginWithUsername ─────────────────────────────────────────────────────

  @override
  Future<void> loginWithUsername(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();

    try {
      await _auth.signInWithEmailAndPassword(
          email: '$cleanUsername@hisoka.com', password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        // Fallback: legacy domain for older accounts
        try {
          await _auth.signInWithEmailAndPassword(
              email: '$cleanUsername@anatanotameni.local', password: password);
        } catch (_) {
          throw Exception('Invalid username or password.');
        }
      } else {
        rethrow;
      }
    }

    if (_auth.currentUser != null) {
      await updateOnlineStatus(_auth.currentUser!.uid, true);
    }
  }

  // ── signOut ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      await updateOnlineStatus(_auth.currentUser!.uid, false);
    }
    await _auth.signOut();
  }

  // ── Profile ───────────────────────────────────────────────────────────────

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
    final update = <String, dynamic>{'isOnline': isOnline};
    if (!isOnline) update['lastSeen'] = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(uid).update(update);
  }
}
