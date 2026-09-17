// lib/firebase_options.dart
// Auto-generated Firebase configuration for Tambola.
// Web config is ready. For Android, see the ⚠️ note below.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android reads from android/app/google-services.json automatically.
        // See README note below about registering com.example.tambola.
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: unsupported platform ${defaultTargetPlatform.name}',
        );
    }
  }

  // ── WEB ──────────────────────────────────────────────────────────────────
  // Same Firebase project as your portfolio app (mychat-bc5a1). Works as-is.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB-Z91ggcEujqe5RQvGiPPgf421ScCni0g',
    appId: '1:750341393850:web:a5f113b3ceb96900682183',
    messagingSenderId: '750341393850',
    projectId: 'mychat-bc5a1',
    authDomain: 'mychat-bc5a1.firebaseapp.com',
    storageBucket: 'mychat-bc5a1.appspot.com',
  );

  // ── ANDROID ───────────────────────────────────────────────────────────────
  // ⚠️  Before running on Android:
  //   1. Go to https://console.firebase.google.com → project "mychat-bc5a1"
  //   2. Click "Add app" → Android
  //   3. Package name: com.example.tambola
  //   4. Download google-services.json → put it in android/app/
  //   5. Replace REPLACE_AFTER_REGISTERING below with the mobilesdk_app_id
  //      shown in the Firebase console (looks like 1:750341393850:android:xxxx)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBvG2H13kjkV3Pmh_DV7dsXzYgTFcYP8Kw',
    appId: 'REPLACE_AFTER_REGISTERING',
    messagingSenderId: '750341393850',
    projectId: 'mychat-bc5a1',
    storageBucket: 'mychat-bc5a1.appspot.com',
  );
}
