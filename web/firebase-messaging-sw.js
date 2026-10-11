/* Replace these public web-app values after running `flutterfire configure`. */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_WITH_FIREBASE_WEB_API_KEY',
  authDomain: 'REPLACE_WITH_FIREBASE_PROJECT.firebaseapp.com',
  projectId: 'REPLACE_WITH_FIREBASE_PROJECT',
  storageBucket: 'REPLACE_WITH_FIREBASE_PROJECT.firebasestorage.app',
  messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
  appId: 'REPLACE_WITH_FIREBASE_WEB_APP_ID',
});

firebase.messaging().onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  self.registration.showNotification(notification.title || 'FloodWatch warning', {
    body: notification.body || 'A new flood warning is available.',
    data: payload.data || {},
  });
});
