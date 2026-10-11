# early_warning_flood_system

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
A FloodWatch application backed by Firebase Authentication, Cloud Firestore,
and Firebase Cloud Messaging.

## Firebase setup

Create a Firebase project, enable Email/Password Authentication and Firestore,
then run `firebase login`, `dart pub global activate flutterfire_cli`, and
`flutterfire configure`. Deploy the database before running the app:

```bash
firebase use YOUR_PROJECT_ID
firebase deploy --only firestore:rules,firestore:indexes
```

Deploy the trusted notification backend:

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

Firebase configuration is intentionally not invented in this repository. Until
`flutterfire configure` is run, the app shows a clear setup screen instead of
failing. Administrator access is enforced by the `admin` Firebase custom claim
and Firestore rules.

## Cross-device notifications

Users register with Gmail or another email address through Firebase
Authentication. FCM sends to registered device tokens, not to a Gmail inbox.
Signing in on two devices registers two tokens for the account. When an admin
publishes a warning, the Cloud Function matches users whose `location` exactly
matches the warning `affectedArea`, sends to all enabled devices, records
delivery results in `notification_logs`, and disables invalid tokens.

Use two physical or supported devices with separate accounts to verify the
Firestore warning, delivery log, foreground dashboard, and background OS
notification. Do not claim delivery success until that test passes.

For web push, replace the placeholders in `web/firebase-messaging-sw.js` and
add the deployed domain to Firebase authorized domains. The GitHub Pages
workflow in `.github/workflows/deploy-web.yml` publishes the web build from
`main`; enable Pages to get the public link. Firebase Hosting is an alternative:
`flutter build web --release` then `firebase deploy --only hosting`.

## Checks

```bash
flutter analyze
flutter test
cd functions && npm run build
```
