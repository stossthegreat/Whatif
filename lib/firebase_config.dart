import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';

/// Firebase project keys (project rivler-3064b) — initialized from Dart, so
/// GoogleService-Info.plist / google-services.json never need to be added to
/// the native projects.
///
/// These are the values from the app registrations for bundle/package
/// `com.rivler.app`. They are NOT secrets — every one of them ships inside
/// the app binary regardless, and Firebase's own docs say so. What protects
/// the project is the API key's platform restrictions and the security
/// rules, not the key being hidden.
class FirebaseCfg {
  static const bool configured = true;

  static FirebaseOptions get current => Platform.isAndroid ? android : ios;

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBVeVUAfIs80W6giMvNzDwCdasSWVylmBc',
    appId: '1:245988086284:ios:335c17b7d68b839159d429',
    messagingSenderId: '245988086284',
    projectId: 'rivler-3064b',
    storageBucket: 'rivler-3064b.firebasestorage.app',
    iosBundleId: 'com.rivler.app',
    // the iOS OAuth client — Firebase wants this for Google Sign-In to work
    // through its SDKs, and it must match the REVERSED_CLIENT_ID URL scheme
    // registered in Info.plist
    iosClientId: '245988086284-1118vejf3c4igo4idrg43olfqtet1p6h.apps.googleusercontent.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBDvlnXI_EeSGtkLGNC2HEbkKBXxuFnNF4',
    appId: '1:245988086284:android:3d7e2073c45cb97c59d429',
    messagingSenderId: '245988086284',
    projectId: 'rivler-3064b',
    storageBucket: 'rivler-3064b.firebasestorage.app',
  );
}
