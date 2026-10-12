// Firebase web configuration is public client configuration. Keep secrets out
// of this worker; delivery is secured by Firebase Auth and server rules.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyD7ydc5hkCpxME1TCRI-dlfsIwnHjmUsiA',
  authDomain: 'early-warning-flood-system.firebaseapp.com',
  projectId: 'early-warning-flood-system',
  storageBucket: 'early-warning-flood-system.firebasestorage.app',
  messagingSenderId: '425949639128',
  appId: '1:425949639128:web:99502f98090632755b02ad',
});

firebase.messaging().onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  self.registration.showNotification(notification.title || 'FloodWatch warning', {
    body: notification.body || 'A new flood warning is available.',
    data: payload.data || {},
    requireInteraction: true,
    silent: false,
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const warningId = event.notification.data && event.notification.data.warningId;
  const target = new URL(
    warningId
      ? `/?warningId=${encodeURIComponent(warningId)}`
      : '/',
    self.registration.scope,
  ).href;
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      const existing = windows.find((window) => window.url.startsWith(self.registration.scope));
      if (existing) {
        existing.navigate(target);
        return existing.focus();
      }
      return clients.openWindow(target);
    }),
  );
});
