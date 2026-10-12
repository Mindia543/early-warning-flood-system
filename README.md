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
Signing in on multiple devices registers a token for each device. When a warning
is published and the Cloud Function is deployed, it sends a normal push
notification with sound to every enabled device, records delivery results in
`notification_logs`, and disables invalid tokens. Without the function, the app
can still use Firestore and show live in-app alerts, but it cannot send
server-triggered notifications while the app is closed.

Use two physical or supported devices with separate accounts to verify the
Firestore warning, delivery log, foreground dashboard, and background OS
notification. Do not claim delivery success until that test passes.

For web push, add the deployed domain to Firebase Authentication > Settings >
Authorized domains. In Firebase Console > Project settings > Cloud Messaging,
open Web Push certificates and copy the public key. Add it to GitHub as a
repository secret named `FIREBASE_WEB_VAPID_KEY`. The Pages workflow passes that
secret into the Flutter build. Users will see one browser permission prompt;
after they choose **Allow**, background notifications can appear outside the
web page.

The notification worker is already configured in
`web/firebase-messaging-sw.js`; do not put private server credentials there.
The GitHub Pages workflow in `.github/workflows/deploy-web.yml` builds from
`main` or `master`.
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

## Free Gmail option on Firebase Spark

If billing is not available, use the free Google Apps Script relay in
`tools/google-apps-script/`. It reads published warnings and sends matching
alerts from Gmail every five minutes without storing a FloodWatch password.
Follow `tools/google-apps-script/README.md`; enter credentials only in Google
Apps Script project properties, never in Flutter or GitHub. This avoids Firebase
Cloud Functions and does not require the Blaze plan. Set the exact warning area
in the relay's private script properties; it remembers warning IDs so it does
not send duplicates.

## In-app cross-device alerts

Every signed-in device listens to the published warning feed in Firestore.
When an admin publishes a warning, it appears in the app on all signed-in
devices and a new-warning banner is shown while the app is open. Background
OS push notifications still require a trusted server trigger; the app does not
depend on Gmail for in-app alerts.

## Checks

```bash
flutter analyze
flutter test
cd functions && npm run build
```
