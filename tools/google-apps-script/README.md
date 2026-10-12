# Free Gmail relay (Google Apps Script)

This relay replaces the Firebase Cloud Function for projects that remain on
Firebase's free Spark plan. It checks Firestore every five minutes and sends a
Gmail message when a new warning is published for the configured area.

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
   | `ALERT_RECIPIENT` | `22u4392@student.mau.edu.ng` |
   | `ALERT_AREA` | Exact `affectedArea` text from the warning |

   `FIREBASE_API_KEY` is the public web key from `lib/firebase_options.dart`.
   No FloodWatch or Gmail password is needed.

4. In the function dropdown, run `sendFloodWatchTestEmail` once and approve
   the Google permissions. Check the recipient inbox.
5. Run `setupFloodWatchRelay` once and approve the remaining permissions.

The first scheduled check marks existing published warnings as already seen,
so it does not send a flood of old messages. A warning published afterward is
sent once. Delivery can take up to about five minutes because the free relay
uses a time trigger.

## Testing a real warning

Create and publish a new warning whose `affectedArea` exactly matches
`ALERT_AREA` (including spaces and capitalization). The next
scheduled run should send it to `ALERT_RECIPIENT`.

To reset the relay for testing, delete the `RELAY_BOOTSTRAPPED` and
`SENT_WARNING_IDS` properties, then run the scheduled function once. The first
run after reset seeds existing warnings without emailing them.

Only published warning content is public; user profiles and account data stay
private. Google Apps Script has daily quotas. Personal accounts currently have a quota
of 100 email recipients per day, which is more than enough for this one-user
alert relay but can change over time.
