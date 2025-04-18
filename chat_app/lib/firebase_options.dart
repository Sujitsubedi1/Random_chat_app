// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
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
        return windows;
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
    apiKey: 'AIzaSyDWuEC5NyoRd-L9q_oMqlBAkKFX_5UrHwU',
    appId: '1:136579318081:web:406ebf4b000ffd42e1e1c0',
    messagingSenderId: '136579318081',
    projectId: 'random-chat-3e819',
    authDomain: 'random-chat-3e819.firebaseapp.com',
    storageBucket: 'random-chat-3e819.firebasestorage.app',
    measurementId: 'G-1R12Z9SLFL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVFuLw6SNTwH-7_Tr0ImAdu1Y7V8HJz_0',
    appId: '1:136579318081:android:eb6ff382ed5e14d2e1e1c0',
    messagingSenderId: '136579318081',
    projectId: 'random-chat-3e819',
    storageBucket: 'random-chat-3e819.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYvavxzE1klQi6X5FoU8fsizrXfi8f4CA',
    appId: '1:136579318081:ios:a17255a033ee361ce1e1c0',
    messagingSenderId: '136579318081',
    projectId: 'random-chat-3e819',
    storageBucket: 'random-chat-3e819.firebasestorage.app',
    iosBundleId: 'com.example.chatApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBYvavxzE1klQi6X5FoU8fsizrXfi8f4CA',
    appId: '1:136579318081:ios:a17255a033ee361ce1e1c0',
    messagingSenderId: '136579318081',
    projectId: 'random-chat-3e819',
    storageBucket: 'random-chat-3e819.firebasestorage.app',
    iosBundleId: 'com.example.chatApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDWuEC5NyoRd-L9q_oMqlBAkKFX_5UrHwU',
    appId: '1:136579318081:web:ff16007d13a17d1be1e1c0',
    messagingSenderId: '136579318081',
    projectId: 'random-chat-3e819',
    authDomain: 'random-chat-3e819.firebaseapp.com',
    storageBucket: 'random-chat-3e819.firebasestorage.app',
    measurementId: 'G-F86HYGVQ64',
  );
}
