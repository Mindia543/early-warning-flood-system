import 'package:firebase_core/firebase_core.dart';

/// This file is intentionally safe to commit before a Firebase project exists.
///
/// Run `flutterfire configure` after creating the Firebase project. The
/// FlutterFire CLI replaces this file with the real, platform-specific public
/// Firebase options. No service-account credentials belong in this file.
class DefaultFirebaseOptions {
  static const bool isConfigured = false;

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured. Run `flutterfire configure` first.',
    );
  }
}
