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

  // ── Password generation ───────────────────────────────────────────────────

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

  // ── Username generation ───────────────────────────────────────────────────

  static const _adjectives = [
    'Swift', 'Cosmic', 'Lucky', 'Brave', 'Silent', 'Wild', 'Dark', 'Crystal',
    'Golden', 'Silver', 'Neon', 'Arctic', 'Velvet', 'Crimson', 'Jade', 'Sapphire',
    'Mystic', 'Shadow', 'Storm', 'Ember', 'Frost', 'Nova', 'Solar', 'Lunar',
    'Vivid', 'Stealth', 'Turbo', 'Radiant', 'Obsidian', 'Cobalt', 'Scarlet',
    'Azure', 'Amber', 'Violet', 'Onyx', 'Ivory', 'Cyan', 'Magenta', 'Teal',
  ];

  static const _nouns = [
    'Fox', 'Wolf', 'Star', 'Moon', 'River', 'Hawk', 'Tiger', 'Comet',
    'Phoenix', 'Falcon', 'Raven', 'Dragon', 'Panda', 'Lynx', 'Eagle',
    'Cobra', 'Viper', 'Panther', 'Jaguar', 'Sparrow', 'Owl', 'Shark',
    'Lotus', 'Orchid', 'Cipher', 'Pulse', 'Vortex', 'Blaze', 'Phantom', 'Echo',
    'Arrow', 'Blade', 'Dusk', 'Flare', 'Glyph', 'Halo', 'Iris', 'Kite',
  ];

  /// Generates a random username of the form [Adjective][Noun][4-digit number]
  /// and retries until one is not already in Firestore.
  Future<String> _generateUniqueUsername() async {
    final rnd = Random();
    while (true) {
      final adj = _adjectives[rnd.nextInt(_adjectives.length)];
      final noun = _nouns[rnd.nextInt(_nouns.length)];
      final number = 1000 + rnd.nextInt(9000); // 1000–9999
      final candidate = '$adj$noun$number';

      final existing = await _firestore
          .collection('users')
          .where('username', isEqualTo: candidate)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) return candidate;
      // collision — loop and try again
    }
  }

  // ── registerPair ──────────────────────────────────────────────────────────

  @override
  Future<Map<String, String>> registerPair(String email) async {
    final emailLower = email.toLowerCase().trim();

    // 1. Guard: email must not already be registered
    final regDoc =
        await _firestore.collection('registrations').doc(emailLower).get();
    if (regDoc.exists) {
      throw Exception('This email is already registered.');
    }

    // 2. Auto-generate two unique usernames
    final username1 = await _generateUniqueUsername();
    final username2 = await _generateUniqueUsername();

    // 3. Shared password
    final password = _generateSecurePassword();

    final user1Email = '${username1.toLowerCase()}@hisoka.com';
    final user2Email = '${username2.toLowerCase()}@hisoka.com';

    // 4. Create Firebase Auth accounts
    final u1Cred = await _auth.createUserWithEmailAndPassword(
        email: user1Email, password: password);
    final uid1 = u1Cred.user!.uid;

    final u2Cred = await _auth.createUserWithEmailAndPassword(
        email: user2Email, password: password);
    final uid2 = u2Cred.user!.uid;

    // 5. Write to Firestore in one batch
    final batch = _firestore.batch();

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
      registeredEmail: pairRef.id,
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

    final roomId =
        uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
    batch.set(_firestore.collection('chat_rooms').doc(roomId), {
      'participants': [uid1, uid2],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 6. Sign in as user1 so the registering device is ready to use
    await _auth.signInWithEmailAndPassword(
        email: user1Email, password: password);

    return {
      'user1_name': username1,
      'user2_name': username2,
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
