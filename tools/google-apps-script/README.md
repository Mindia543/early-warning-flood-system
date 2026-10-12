# Free Gmail relay (Google Apps Script)

This relay replaces the Firebase Cloud Function for projects that remain on
Firebase's free Spark plan. It checks Firestore every five minutes and sends a
Gmail message when a new warning is published for the signed-in user's exact
monitored area.

It does not put a Gmail password, SMTP password, or service-account key in the
Flutter app or this repository.

## One-time setup

1. Open [script.google.com](https://script.google.com/) while signed in to the
   Gmail account that should send the alerts. Create a new project.
2. Copy `Code.gs` from this folder into the Apps Script editor and save it.
3. Open **Project Settings > Script properties** and add:

   | Property | Value |
   | --- | --- |
   | `FIREBASE_API_KEY` | The web API key from `lib/firebase_options.dart` |
   | `FIREBASE_PROJECT_ID` | `early-warning-flood-system` (optional; this is the default) |
   | `FIREBASE_AUTH_EMAIL` | The email used to sign in to FloodWatch |
   | `FIREBASE_AUTH_PASSWORD` | That FloodWatch account password |
   | `ALERT_RECIPIENT` | `22u4330@student.mau.edu.ng` |
   | `ALERT_AREA` | Optional exact area; leave empty to use the profile location |

   The password is entered only in Google's private Script properties. Do not
   send it in chat or commit it to GitHub. A separate FloodWatch account is
   preferable if you do not want to store your main account password there.

4. In the function dropdown, run `sendFloodWatchTestEmail` once and approve
   the Google permissions. Check the recipient inbox.
5. Run `setupFloodWatchRelay` once and approve the remaining permissions.

The first scheduled check marks existing published warnings as already seen,
so it does not send a flood of old messages. A warning published afterward is
sent once. Delivery can take up to about five minutes because the free relay
uses a time trigger.

## Testing a real warning

Create and publish a new warning whose `affectedArea` exactly matches the
user's profile `location` (including spaces and capitalization). The next
scheduled run should send it to `ALERT_RECIPIENT`.

To reset the relay for testing, delete the `RELAY_BOOTSTRAPPED` and
`SENT_WARNING_IDS` properties, then run the scheduled function once. The first
run after reset seeds existing warnings without emailing them.

Google Apps Script has daily quotas. Personal accounts currently have a quota
of 100 email recipients per day, which is more than enough for this one-user
alert relay but can change over time.
