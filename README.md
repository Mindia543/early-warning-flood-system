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

The optional trusted notification backend (Cloud Functions) requires the Firebase
Blaze plan. If you are staying on Spark, do not deploy Functions; server-triggered
push/email delivery will not run.

To enable the backend on a billed project:

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
publishes a warning and the Cloud Function is deployed, it matches users whose
`location` exactly matches the warning `affectedArea`, sends to all enabled
devices, records delivery results in `notification_logs`, and disables invalid
tokens. Without the function, the app can still use Firestore, but it cannot send
server-triggered push notifications or email.

Use two physical or supported devices with separate accounts to verify the
Firestore warning, delivery log, foreground dashboard, and background OS
notification. Do not claim delivery success until that test passes.

For web push, replace the placeholders in `web/firebase-messaging-sw.js` and
add the deployed domain to Firebase authorized domains. The GitHub Pages
workflow in `.github/workflows/deploy-web.yml` builds from `main` or `master`.
In the repository, choose **Settings > Pages > Build and deployment > Source >
GitHub Actions** to publish and get the public link. Firebase Hosting is an
alternative:
`flutter build web --release` then `firebase deploy --only hosting`.

## Email delivery setup

When Cloud Functions is deployed on the Blaze plan, the same publish trigger
sends email to each matching user's email address through Gmail SMTP. Use a
dedicated Gmail account and a Google App Password.
Store both values in Firebase Secret Manager; never put them in Flutter, `.env`
files committed to Git, or GitHub source:

```bash
firebase functions:secrets:set SMTP_USER
firebase functions:secrets:set SMTP_PASSWORD
```

The SMTP sender is `SMTP_USER`. The backend uses `smtp.gmail.com` on port 465
with SSL. Deploy after setting both secrets:

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

The app profile has separate push and email switches. Email results are stored
in `notification_logs` with `channel: "email"`. Gmail requires 2-Step
Verification and an App Password for this type of SMTP connection.

## Checks

```bash
flutter analyze
flutter test
cd functions && npm run build
```
