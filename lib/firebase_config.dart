import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';

/// Firebase project keys (project rivlr-9761e) — initialized from Dart, so the
/// plist/json never need to be added to the native projects.
class FirebaseCfg {
  static const bool configured = true;

  static FirebaseOptions get current => Platform.isAndroid ? android : ios;

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCnx4T8JlRDu4RecdLd21f5y04P8ZUIaC8',
    appId: '1:253597616968:ios:93c6ce60362e86b7f6017d',
    messagingSenderId: '253597616968',
    projectId: 'rivlr-9761e',
    storageBucket: 'rivlr-9761e.firebasestorage.app',
    iosBundleId: 'com.rivler.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAQQ1gOfFAWZB5Xq_OISgPyb7_R_pPnFqY',
    appId: '1:253597616968:android:75f95ade9d018d6bf6017d',
    messagingSenderId: '253597616968',
    projectId: 'rivlr-9761e',
    storageBucket: 'rivlr-9761e.firebasestorage.app',
  );
}
