import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCB1ODAxRCnznxU4ca5d2OQTMJ2zHKGLZY',
    appId: '1:664228815092:web:4164dd3f9c22dbd3e1bea1',
    messagingSenderId: '664228815092',
    projectId: 'antn-91353',
    authDomain: 'antn-91353.firebaseapp.com',
    databaseURL: 'https://antn-91353-default-rtdb.firebaseio.com',
    storageBucket: 'antn-91353.firebasestorage.app',
    measurementId: 'G-H8CR3K4TBX',
  );

  // NOTE: These are fallback configurations for Android and iOS.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyComoJwuI1xYYHHJOy5ThS0BbZmGNIr_lw',
    appId: '1:664228815092:android:0799cf7520a64349e1bea1',
    messagingSenderId: '664228815092',
    projectId: 'antn-91353',
    databaseURL: 'https://antn-91353-default-rtdb.firebaseio.com',
    storageBucket: 'antn-91353.firebasestorage.app',
  );

  // To get the correct appIds for mobile, you should run `flutterfire configure`

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAqTTUuja1uur-72G91pGSEkUOAB13IbwI',
    appId: '1:664228815092:ios:1687c4a38e8df515e1bea1',
    messagingSenderId: '664228815092',
    projectId: 'antn-91353',
    databaseURL: 'https://antn-91353-default-rtdb.firebaseio.com',
    storageBucket: 'antn-91353.firebasestorage.app',
    iosClientId:
        '664228815092-3d6o9i537t23eist053eucllpqgqutei.apps.googleusercontent.com',
    iosBundleId: 'com.premium.chat.anataNoTameNi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAqTTUuja1uur-72G91pGSEkUOAB13IbwI',
    appId: '1:664228815092:ios:1687c4a38e8df515e1bea1',
    messagingSenderId: '664228815092',
    projectId: 'antn-91353',
    databaseURL: 'https://antn-91353-default-rtdb.firebaseio.com',
    storageBucket: 'antn-91353.firebasestorage.app',
    iosClientId:
        '664228815092-3d6o9i537t23eist053eucllpqgqutei.apps.googleusercontent.com',
    iosBundleId: 'com.premium.chat.anataNoTameNi',
  );
}
